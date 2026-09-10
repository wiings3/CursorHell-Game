extends Node2D
class_name CursorHellBaseLevel

signal level_completed(level_number: int, final_score: int)
signal level_failed(level_number: int, final_score: int)
signal continue_requested

const ProjectileScene := preload("res://Scenes/Components/Projectile.tscn")
const SfxScript = preload("res://scripts/sfx.gd")

const DESIGN_SIZE := Vector2(1600.0, 900.0)
const ARENA := Rect2(390.0, 72.0, 820.0, 756.0)
const PLAYER_RADIUS := 10.0
const NEAR_RADIUS := 40.0
const DEATH_FEEDBACK_TIME := 0.42
const COUNTDOWN_TIME := 3.90

var rng := RandomNumberGenerator.new()
var warnings: Array = []

var state := "intro"
var time_left := 0.0
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

# Main sets this when the level is loaded. Levels stay independent of the
# loader while still being able to present the correct completion action.
var has_next_level: bool = false

@onready var player: CursorHellPlayer = %Player
@onready var projectile_layer: Node2D = %Projectiles
@onready var warning_layer: CursorHellWarningLayer = %WarningLayer

# The complete HUD is now a reusable component scene. BaseLevel talks to the
# component root instead of reaching through another scene's unique-node scope.
@onready var hud: CursorHellLevelHUD = %LevelHUD
@onready var ui_layer: CanvasLayer = hud
@onready var timer_label: Label = hud.timer_label
@onready var score_label: Label = hud.score_label
@onready var tutorial_label: Label = hud.tutorial_label
@onready var combo_label: Label = hud.combo_label
@onready var message_scrim: ColorRect = hud.message_scrim
@onready var message_border: ColorRect = hud.message_border
@onready var message_panel: ColorRect = hud.message_panel
@onready var message_title: Label = hud.message_title
@onready var message_subtitle: Label = hud.message_subtitle
@onready var message_body: Label = hud.message_body
@onready var hit_flash: ColorRect = hud.hit_flash
@onready var hit_label: Label = hud.hit_label
@onready var graze_popup_label: Label = hud.graze_popup_label
@onready var countdown_label: Label = hud.countdown_label
@onready var countdown_subtitle: Label = hud.countdown_subtitle

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
			if state == "won":
				if has_next_level:
					continue_requested.emit()
				else:
					_reset_round(true)
				return
			if state == "intro" or state == "dead":
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
					message_subtitle.text = _get_pause_subtitle()
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
	time_left = maxf(0.0, _get_round_time() - elapsed)
	score += delta * 10.0
	combo_time -= delta
	near_flash = maxf(0.0, near_flash - delta * 2.0)
	if combo_time <= 0.0:
		combo = 0

	var current_phase := _get_phase()
	if current_phase != last_phase:
		last_phase = current_phase
		spawn_clock = 999.0 if current_phase == 0 else 0.65

	_update_level_tutorial()

	if current_phase > 0:
		spawn_clock -= delta
		if spawn_clock <= 0.0:
			_schedule_level_projectile(current_phase)
			spawn_clock = _get_spawn_interval(current_phase)

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

func queue_projectile_warning(side: int, lane: float, speed: float, radius: float, delay: float) -> void:
	warnings.append({
		"side": side,
		"lane": lane,
		"speed": speed,
		"radius": radius,
		"time": delay,
		"max": delay
	})

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

	var bullet: CursorHellProjectile = ProjectileScene.instantiate() as CursorHellProjectile
	if bullet == null:
		push_error("Cursor Hell: Projectile.tscn must use CursorHellProjectile.")
		return

	bullet.position = spawn_position
	bullet.velocity = velocity
	bullet.radius = radius
	projectile_layer.add_child(bullet)
	SfxScript.play_projectile(self)

func _check_projectiles(current_phase: int) -> void:
	for child in projectile_layer.get_children():
		var bullet := child as CursorHellProjectile
		if bullet == null or not is_instance_valid(bullet) or bullet.is_queued_for_deletion():
			continue

		# Projectile history and player position are intentionally compared in the
		# same local 1600x900 coordinate space. Do not convert these to globals.
		var closest := _closest_point_on_segment(player.position, bullet.previous_position, bullet.position)
		var hit_distance := PLAYER_RADIUS + bullet.radius
		if closest.distance_to(player.position) <= hit_distance:
			_begin_death("Projectile contact")
			return

		if _graze_enabled_for_phase(current_phase):
			var distance := player.position.distance_to(bullet.position)
			if distance <= NEAR_RADIUS + bullet.radius and not bullet.has_meta("grazed"):
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
		if not outer.has_point(bullet.position) and bullet.age > 1.0:
			bullet.queue_free()

func _swept_player_collision(start: Vector2, finish: Vector2) -> void:
	if state != "playing":
		return

	for child in projectile_layer.get_children():
		var bullet := child as CursorHellProjectile
		if bullet == null or not is_instance_valid(bullet) or bullet.is_queued_for_deletion():
			continue
		var closest := _closest_point_on_segment(bullet.position, start, finish)
		if closest.distance_to(bullet.position) <= PLAYER_RADIUS + bullet.radius:
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
	time_left = _get_round_time()
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
	_update_level_tutorial()
	_update_ui()

	if start_now:
		_start_countdown()
	else:
		state = "intro"
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_show_message_panel(false)
		message_title.text = _get_intro_title()
		message_subtitle.text = _get_intro_subtitle()
		message_body.text = _get_intro_body()

func _start_countdown() -> void:
	state = "countdown"
	countdown_left = COUNTDOWN_TIME
	countdown_step = -1
	_hide_message_panel()
	_capture_mouse()
	tutorial_label.text = _get_countdown_tutorial_text()
	countdown_label.visible = true
	countdown_subtitle.visible = true
	countdown_subtitle.text = _get_countdown_subtitle()

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
		_update_level_tutorial()

func _refresh_countdown_step() -> void:
	var new_step := 0
	# Synced to the current 3.9 second announcer WAV:
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

	for child in projectile_layer.get_children():
		if is_instance_valid(child):
			child.set_physics_process(false)
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
	message_title.text = _get_death_title()
	message_subtitle.text = _get_death_subtitle()
	message_body.text = _get_death_body(pending_death_reason, elapsed, final_score, high_score)
	level_failed.emit(_get_level_number(), final_score)

func _win() -> void:
	if state != "playing":
		return

	score += _get_completion_bonus()
	score_punch = 1.0
	high_score = maxi(high_score, int(score))
	state = "won"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	tutorial_label.text = _get_win_tutorial_text()
	SfxScript.play_level_complete(self)
	_show_message_panel(true)
	message_title.text = _get_win_title()
	message_subtitle.text = _get_win_subtitle()
	message_body.text = _get_win_body(int(score), high_score)
	_update_ui()
	level_completed.emit(_get_level_number(), int(score))

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

func _get_win_action_text() -> String:
	if has_next_level:
		return "CLICK TO CONTINUE\nR = REPLAY LEVEL"
	return "CLICK OR PRESS R TO PLAY AGAIN"

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().quit()

# Level-specific hooks ---------------------------------------------------------
# Subclasses override these. BaseLevel owns the reusable runtime systems while
# each level owns its pacing, text, projectile rules, and scoring details.

func _get_level_number() -> int:
	return 0

func _get_round_time() -> float:
	return 45.0

func _get_completion_bonus() -> float:
	return 0.0

func _get_phase() -> int:
	return 0

func _update_level_tutorial() -> void:
	pass

func _schedule_level_projectile(_current_phase: int) -> void:
	pass

func _get_spawn_interval(_current_phase: int) -> float:
	return 1.0

func _graze_enabled_for_phase(_current_phase: int) -> bool:
	return true

func _get_intro_title() -> String:
	return "LEVEL"

func _get_intro_subtitle() -> String:
	return ""

func _get_intro_body() -> String:
	return "CLICK TO BEGIN"

func _get_pause_subtitle() -> String:
	return "PAUSED"

func _get_countdown_tutorial_text() -> String:
	return "GET READY"

func _get_countdown_subtitle() -> String:
	return ""

func _get_death_title() -> String:
	return "RUN ENDED"

func _get_death_subtitle() -> String:
	return "IMPACT"

func _get_death_body(reason: String, run_time: float, final_score: int, best_score: int) -> String:
	return "%s\n\nTIME   %s\nSCORE  %s\nBEST   %s\n\nCLICK OR PRESS R TO RETRY" % [reason.to_upper(), _format_time(run_time), _format_score(final_score), _format_score(best_score)]

func _get_win_title() -> String:
	return "LEVEL COMPLETE"

func _get_win_subtitle() -> String:
	return "CLEARED"

func _get_win_tutorial_text() -> String:
	return "LEVEL COMPLETE"

func _get_win_body(final_score: int, best_score: int) -> String:
	return "FINAL SCORE   %s\nBEST SCORE    %s\n\n%s" % [_format_score(final_score), _format_score(best_score), _get_win_action_text()]
