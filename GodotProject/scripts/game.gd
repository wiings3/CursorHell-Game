extends Node2D

const ProjectileScript = preload("res://scripts/projectile.gd")
const SfxScript = preload("res://scripts/sfx.gd")

const DESIGN_SIZE := Vector2(1600.0, 900.0)
const ARENA := Rect2(390.0, 72.0, 820.0, 756.0)
const ROUND_TIME := 45.0
const PLAYER_RADIUS := 10.0
const NEAR_RADIUS := 40.0
const DEATH_FEEDBACK_TIME := 0.42
const COUNTDOWN_TIME := 3.90

var rng := RandomNumberGenerator.new()
var warnings: Array = []

var state := "intro"
var time_left := ROUND_TIME
var elapsed := 0.0
var score := 0.0
var combo := 0
var combo_time := 0.0
var near_flash := 0.0
var spawn_clock := 999.0
var moved_distance := 0.0
var last_phase := -1
var high_score := 0
var shake := 0.0
var viewport_scale := 1.0
var viewport_offset := Vector2.ZERO
var death_feedback_left := 0.0
var pending_death_reason := ""
var hit_flash_alpha := 0.0
var graze_popup_time := 0.0
var graze_popup_origin := Vector2.ZERO
var score_punch := 0.0
var countdown_left := 0.0
var countdown_step := -1
var last_lane_by_side := [-10.0, -10.0, -10.0, -10.0]

# World and UI nodes now live in Main.tscn. Gameplay code only controls them.
@onready var player: CursorHellPlayer = %Player
@onready var projectile_layer: Node2D = %Projectiles
@onready var warning_layer: CursorHellWarningLayer = %WarningLayer

@onready var ui_layer: CanvasLayer = %UI
@onready var timer_label: Label = %TimerLabel
@onready var score_label: Label = %ScoreLabel
@onready var tutorial_label: Label = %TutorialLabel
@onready var combo_label: Label = %ComboLabel
@onready var message_scrim: ColorRect = %MessageScrim
@onready var message_border: ColorRect = %MessageBorder
@onready var message_panel: ColorRect = %MessagePanel
@onready var message_title: Label = %MessageTitle
@onready var message_subtitle: Label = %MessageSubtitle
@onready var message_body: Label = %MessageBody
@onready var hit_flash: ColorRect = %HitFlash
@onready var hit_label: Label = %HitLabel
@onready var graze_popup_label: Label = %GrazePopupLabel
@onready var countdown_label: Label = %CountdownLabel
@onready var countdown_subtitle: Label = %CountdownSubtitle

func _ready() -> void:
	rng.randomize()
	warning_layer.warnings = warnings
	get_viewport().size_changed.connect(_apply_viewport_layout)
	_apply_viewport_layout()
	_reset_round(false)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			if state == "intro" or state == "dead" or state == "won":
				_reset_round(true)
				return
			if state == "paused":
				_capture_mouse()
				state = "playing"
				_hide_message_panel()
				return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.physical_keycode == KEY_R:
				_reset_round(true)
				return
			if key_event.keycode == KEY_ESCAPE:
				if state == "playing" or state == "countdown":
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
					state = "paused"
					_show_message_panel(false)
					message_title.text = "PAUSED"
					message_subtitle.text = "LEVEL 1 — FIRST CONTACT"
					message_body.text = "Mouse released.\n\nCLICK TO RESUME\n\nR = restart"
					countdown_label.visible = false
					countdown_subtitle.visible = false
				elif state == "paused":
					_capture_mouse()
					state = "playing"
					_hide_message_panel()
				return

	if (state == "playing" or state == "countdown") and event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var old_position := player.position
		var logical_motion := motion.relative / maxf(viewport_scale, 0.001)
		var next_position := player.position + logical_motion
		next_position.x = clampf(next_position.x, ARENA.position.x + PLAYER_RADIUS, ARENA.end.x - PLAYER_RADIUS)
		next_position.y = clampf(next_position.y, ARENA.position.y + PLAYER_RADIUS, ARENA.end.y - PLAYER_RADIUS)
		player.position = next_position
		moved_distance += old_position.distance_to(next_position)
		if state == "playing":
			_swept_player_collision(old_position, next_position)

func _physics_process(delta: float) -> void:
	if state == "countdown":
		_update_countdown(delta)
		return

	if state == "dying":
		death_feedback_left -= delta
		if death_feedback_left <= 0.0:
			_show_death_panel()
		return

	if state != "playing":
		return

	elapsed += delta
	time_left = maxf(0.0, ROUND_TIME - elapsed)
	score += delta * 10.0
	combo_time -= delta
	near_flash = maxf(0.0, near_flash - delta * 2.0)
	if combo_time <= 0.0:
		combo = 0

	var current_phase := _phase()
	if current_phase != last_phase:
		last_phase = current_phase
		spawn_clock = 999.0 if current_phase == 0 else 0.65

	_update_tutorial()

	if current_phase > 0:
		spawn_clock -= delta
		if spawn_clock <= 0.0:
			_schedule_projectile(current_phase)
			spawn_clock = _spawn_interval(current_phase)

	_update_warnings(delta)
	_check_projectiles(current_phase)
	if state != "playing":
		return

	_update_ui()
	if time_left <= 0.0:
		_win()

func _process(delta: float) -> void:
	if hit_flash_alpha > 0.0:
		hit_flash_alpha = maxf(0.0, hit_flash_alpha - delta * 2.8)
		if hit_flash != null:
			hit_flash.color = Color(1.0, 0.12, 0.06, hit_flash_alpha)

	if graze_popup_time > 0.0:
		graze_popup_time = maxf(0.0, graze_popup_time - delta)
		if graze_popup_label != null:
			graze_popup_label.visible = graze_popup_time > 0.0
			graze_popup_label.position = graze_popup_origin + Vector2(-110.0, -58.0 - (0.65 - graze_popup_time) * 18.0)
			graze_popup_label.modulate.a = clampf(graze_popup_time / 0.25, 0.0, 1.0)
	elif graze_popup_label != null:
		graze_popup_label.visible = false

	if score_punch > 0.0:
		score_punch = maxf(0.0, score_punch - delta * 5.0)
		var bump := 1.0 + sin(score_punch * PI) * 0.08
		score_label.scale = Vector2.ONE * bump
	elif score_label != null:
		score_label.scale = Vector2.ONE

	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 20.0)
		var shake_offset := Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake))
		position = viewport_offset + shake_offset * viewport_scale
	else:
		position = viewport_offset

func _apply_viewport_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	viewport_scale = minf(
		viewport_size.x / DESIGN_SIZE.x,
		viewport_size.y / DESIGN_SIZE.y
	)
	viewport_offset = (viewport_size - DESIGN_SIZE * viewport_scale) * 0.5

	scale = Vector2.ONE * viewport_scale
	position = viewport_offset

	if ui_layer != null:
		ui_layer.transform = Transform2D(
			0.0,
			Vector2.ONE * viewport_scale,
			0.0,
			viewport_offset
		)

func _phase() -> int:
	if elapsed < 7.0:
		return 0
	if elapsed < 20.0:
		return 1
	if elapsed < 32.0:
		return 2
	if elapsed < 40.0:
		return 3
	return 4

func _update_tutorial() -> void:
	match _phase():
		0:
			if moved_distance < 80.0:
				tutorial_label.text = "MOVE THE MOUSE\nYour character is the cursor."
			else:
				tutorial_label.text = "GOOD\nMovement is immediate. Stay inside the arena."
		1:
			tutorial_label.text = "READ THE EDGE\nOrange markers show where a projectile will enter."
		2:
			tutorial_label.text = "CHECK EVERY SIDE\nWarnings can now appear on all four edges."
		3:
			tutorial_label.text = "GRAZE = BONUS\nPass close without touching to build score."
		_:
			tutorial_label.text = "FINAL 5 SECONDS\nSmall movements. Stay calm."

func _schedule_projectile(current_phase: int) -> void:
	var side := 0
	var lane := 0.5
	var speed := 150.0
	var radius := 7.0
	var delay := 1.0

	if current_phase == 1:
		side = 0 if rng.randf() < 0.5 else 1
		lane = rng.randf_range(0.14, 0.86)
		speed = rng.randf_range(135.0, 155.0)
		delay = 1.15
	elif current_phase == 2:
		side = rng.randi_range(0, 3)
		lane = rng.randf_range(0.12, 0.88)
		speed = rng.randf_range(145.0, 175.0)
		delay = 1.0
	elif current_phase == 3:
		side = rng.randi_range(0, 3)
		lane = rng.randf_range(0.10, 0.90)
		speed = rng.randf_range(155.0, 188.0)
		radius = rng.randf_range(7.0, 8.0)
		delay = 0.92
	else:
		side = rng.randi_range(0, 3)
		lane = rng.randf_range(0.10, 0.90)
		speed = rng.randf_range(165.0, 195.0)
		radius = 7.5
		delay = 0.85

	# Level 1 should never create visually stacked "gotcha" lanes on the same edge.
	# A small reroll keeps the random system readable without making it predictable.
	for attempt in range(3):
		if absf(lane - float(last_lane_by_side[side])) >= 0.09:
			break
		lane = rng.randf_range(0.12, 0.88)
	last_lane_by_side[side] = lane

	warnings.append({
		"side": side,
		"lane": lane,
		"speed": speed,
		"radius": radius,
		"time": delay,
		"max": delay
	})

func _spawn_interval(current_phase: int) -> float:
	match current_phase:
		1:
			return rng.randf_range(1.80, 2.10)
		2:
			return rng.randf_range(1.50, 1.75)
		3:
			return rng.randf_range(1.27, 1.47)
		_:
			return rng.randf_range(1.10, 1.28)

func _update_warnings(delta: float) -> void:
	for i in range(warnings.size() - 1, -1, -1):
		var warning: Dictionary = warnings[i]
		warning["time"] = float(warning["time"]) - delta
		if float(warning["time"]) <= 0.0:
			_release_warning(warning)
			warnings.remove_at(i)

func _release_warning(warning: Dictionary) -> void:
	var side := int(warning["side"])
	var lane := float(warning["lane"])
	var speed := float(warning["speed"])
	var radius := float(warning["radius"])
	var padding := 26.0
	var spawn_position := Vector2.ZERO
	var velocity := Vector2.ZERO

	match side:
		0:
			spawn_position = Vector2(ARENA.position.x - padding, ARENA.position.y + ARENA.size.y * lane)
			velocity = Vector2(speed, 0.0)
		1:
			spawn_position = Vector2(ARENA.end.x + padding, ARENA.position.y + ARENA.size.y * lane)
			velocity = Vector2(-speed, 0.0)
		2:
			spawn_position = Vector2(ARENA.position.x + ARENA.size.x * lane, ARENA.position.y - padding)
			velocity = Vector2(0.0, speed)
		_:
			spawn_position = Vector2(ARENA.position.x + ARENA.size.x * lane, ARENA.end.y + padding)
			velocity = Vector2(0.0, -speed)

	var bullet := ProjectileScript.new()
	bullet.position = spawn_position
	bullet.velocity = velocity
	bullet.radius = radius
	projectile_layer.add_child(bullet)
	SfxScript.play_projectile(self)

func _check_projectiles(current_phase: int) -> void:
	for bullet in projectile_layer.get_children():
		if not is_instance_valid(bullet) or bullet.is_queued_for_deletion():
			continue

		var closest := _closest_point_on_segment(player.position, bullet.previous_position, bullet.position)
		var hit_distance := PLAYER_RADIUS + float(bullet.radius)
		if closest.distance_to(player.position) <= hit_distance:
			_begin_death("Projectile contact")
			return

		if current_phase >= 3:
			var distance := player.position.distance_to(bullet.position)
			if distance <= NEAR_RADIUS + float(bullet.radius) and not bullet.has_meta("grazed"):
				bullet.set_meta("grazed", true)
				combo = mini(combo + 1, 8)
				combo_time = 1.6
				var bonus := 50 * maxi(combo, 1)
				score += bonus
				score_punch = 1.0
				player.flash_near_miss()
				near_flash = 1.0
				graze_popup_origin = player.position
				graze_popup_time = 0.65
				graze_popup_label.text = "GRAZE  +%d" % bonus
				graze_popup_label.modulate.a = 1.0
				graze_popup_label.visible = true
				SfxScript.play_graze(self, combo)

		var outer := ARENA.grow(100.0)
		if not outer.has_point(bullet.position) and float(bullet.age) > 1.0:
			bullet.queue_free()

func _swept_player_collision(start: Vector2, finish: Vector2) -> void:
	if state != "playing":
		return

	for bullet in projectile_layer.get_children():
		if not is_instance_valid(bullet) or bullet.is_queued_for_deletion():
			continue
		var closest := _closest_point_on_segment(bullet.position, start, finish)
		if closest.distance_to(bullet.position) <= PLAYER_RADIUS + float(bullet.radius):
			player.position = closest
			_begin_death("Projectile contact")
			return

func _closest_point_on_segment(point: Vector2, start: Vector2, finish: Vector2) -> Vector2:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return start
	var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return start + segment * t

func _capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _reset_player_position() -> void:
	player.position = ARENA.position + Vector2(ARENA.size.x * 0.5, ARENA.size.y * 0.53)

func _reset_round(start_now: bool) -> void:
	for child in projectile_layer.get_children():
		child.queue_free()
	warnings.clear()
	time_left = ROUND_TIME
	elapsed = 0.0
	score = 0.0
	combo = 0
	combo_time = 0.0
	near_flash = 0.0
	spawn_clock = 999.0
	moved_distance = 0.0
	last_phase = -1
	death_feedback_left = 0.0
	pending_death_reason = ""
	hit_flash_alpha = 0.0
	graze_popup_time = 0.0
	score_punch = 0.0
	countdown_left = 0.0
	countdown_step = -1
	last_lane_by_side = [-10.0, -10.0, -10.0, -10.0]
	hit_flash.color = Color(1.0, 0.12, 0.06, 0.0)
	hit_label.visible = false
	graze_popup_label.visible = false
	graze_popup_label.modulate.a = 1.0
	countdown_label.visible = false
	countdown_subtitle.visible = false
	score_label.scale = Vector2.ONE
	player.set_process(true)
	_reset_player_position()
	_update_tutorial()
	_update_ui()

	if start_now:
		_start_countdown()
	else:
		state = "intro"
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_show_message_panel(false)
		message_title.text = "FIRST CONTACT"
		message_subtitle.text = "LEVEL 1 — TRAINING"
		message_body.text = "Your character IS the cursor.\n\nMove the mouse to move.\nDodge the orange projectiles.\nSurvive for 45 seconds.\n\nWarnings show where danger will enter.\n\nCLICK TO BEGIN"

func _start_countdown() -> void:
	state = "countdown"
	countdown_left = COUNTDOWN_TIME
	countdown_step = -1
	_hide_message_panel()
	_capture_mouse()
	tutorial_label.text = "GET READY\nMove the mouse and find a comfortable position."
	countdown_label.visible = true
	countdown_subtitle.visible = true
	countdown_subtitle.text = "FIRST CONTACT"

	# countdown.wav contains the full announcer cue: "3, 2, 1, GO!"
	# Play it once when the countdown begins.
	SfxScript.play_countdown(self, 3)

	_refresh_countdown_step()

func _update_countdown(delta: float) -> void:
	countdown_left = maxf(0.0, countdown_left - delta)
	_refresh_countdown_step()
	if countdown_left <= 0.0:
		state = "playing"
		countdown_label.visible = false
		countdown_subtitle.visible = false
		_update_tutorial()

func _refresh_countdown_step() -> void:
	var new_step := 0
	# countdown.wav is 3.9 seconds long.
	# Synced to the announcer:
	#   0.00s -> 3
	#   0.86s -> 2
	#   1.74s -> 1
	#   2.58s -> GO
	if countdown_left > 3.04:
		new_step = 3
	elif countdown_left > 2.16:
		new_step = 2
	elif countdown_left > 1.32:
		new_step = 1
	else:
		new_step = 0

	if new_step == countdown_step:
		return

	countdown_step = new_step
	if new_step > 0:
		countdown_label.text = str(new_step)
		countdown_label.add_theme_color_override("font_color", Color(0.98, 0.97, 0.93))
	else:
		countdown_label.text = "GO"
		countdown_label.add_theme_color_override("font_color", Color(1.0, 0.70, 0.24))

func _begin_death(reason: String) -> void:
	if state != "playing":
		return

	state = "dying"
	pending_death_reason = reason
	death_feedback_left = DEATH_FEEDBACK_TIME
	hit_flash_alpha = 0.28
	hit_flash.color = Color(1.0, 0.12, 0.06, hit_flash_alpha)
	hit_label.position = player.position + Vector2(-80.0, -62.0)
	hit_label.visible = true
	shake = 7.0
	SfxScript.play_hit(self)

	for bullet in projectile_layer.get_children():
		if is_instance_valid(bullet):
			bullet.set_physics_process(false)
	player.set_process(false)

func _show_death_panel() -> void:
	if state != "dying":
		return

	state = "dead"
	var final_score := int(score)
	high_score = maxi(high_score, final_score)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	hit_label.visible = false
	_show_message_panel(true)
	message_title.text = "RUN ENDED"
	message_subtitle.text = "LEVEL 1 — IMPACT"
	message_body.text = "%s\n\nTIME   %s / 0:45\nSCORE  %s\nBEST   %s\n\nCLICK OR PRESS R TO RETRY" % [pending_death_reason.to_upper(), _format_time(elapsed), _format_score(final_score), _format_score(high_score)]

func _win() -> void:
	if state != "playing":
		return

	score += 2500.0
	score_punch = 1.0
	high_score = maxi(high_score, int(score))
	state = "won"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	tutorial_label.text = "LEVEL COMPLETE\nFIRST CONTACT CLEARED"
	SfxScript.play_level_complete(self)
	_show_message_panel(true)
	message_title.text = "LEVEL COMPLETE"
	message_subtitle.text = "FIRST CONTACT CLEARED"
	message_body.text = "45 SECONDS SURVIVED\n\nCOMPLETION BONUS   +2,500\nFINAL SCORE        %s\nBEST SCORE         %s\n\nMovement, warnings, dodging and grazing learned.\n\nCLICK OR PRESS R TO PLAY AGAIN" % [_format_score(int(score)), _format_score(high_score)]
	_update_ui()

func _show_message_panel(animate: bool) -> void:
	message_scrim.visible = true
	message_border.visible = true
	message_panel.visible = true

	if not animate:
		message_scrim.modulate.a = 1.0
		message_border.modulate.a = 1.0
		message_panel.modulate.a = 1.0
		return

	message_scrim.modulate.a = 0.0
	message_border.modulate.a = 0.0
	message_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(message_scrim, "modulate:a", 1.0, 0.16)
	tween.tween_property(message_border, "modulate:a", 1.0, 0.18)
	tween.tween_property(message_panel, "modulate:a", 1.0, 0.18)

func _hide_message_panel() -> void:
	message_scrim.visible = false
	message_border.visible = false
	message_panel.visible = false

func _update_ui() -> void:
	if timer_label == null:
		return
	var seconds_left := int(ceil(time_left))
	timer_label.text = "%d:%02d" % [int(seconds_left / 60), seconds_left % 60]
	score_label.text = _format_score(int(score))
	if combo > 1 and combo_time > 0.0:
		combo_label.text = "GRAZE COMBO  x%d" % combo
	elif near_flash > 0.0:
		combo_label.text = "GRAZE"
	else:
		combo_label.text = ""

func _format_time(seconds: float) -> String:
	var whole := int(floor(seconds))
	return "%d:%02d" % [int(whole / 60), whole % 60]

func _format_score(value: int) -> String:
	var remaining := str(value)
	var result := ""
	while remaining.length() > 3:
		result = "," + remaining.substr(remaining.length() - 3, 3) + result
		remaining = remaining.substr(0, remaining.length() - 3)
	return remaining + result

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().quit()
