extends "res://scripts/levels/base_level.gd"
class_name CursorHellPrecisionPrototype

const EnemyScript = preload("res://scripts/objects/micro_enemy.gd")
const BulletScript = preload("res://scripts/objects/micro_bullet.gd")
const CrosshairScript = preload("res://scripts/objects/micro_crosshair.gd")

const BODY_SPEED := 305.0
const BODY_RADIUS := 10.0
const FIRE_COOLDOWN := 0.11
const QUICK_COUNTDOWN := 0.55
const TOTAL_ENEMIES := 10

# Four deliberately small combat waves. The room is meant to answer one thing:
# does moving with WASD while independently aiming and shooting with the mouse
# create a more active core than moving the cursor itself?
const WAVES := [
	{
		"gap": 0.30,
		"enemies": [
			{"position": Vector2(1080.0, 245.0), "kind": "gunner", "radius": 26.0, "spawn": 0.18, "initial": 0.78, "repeat": 1.30, "score": 1000}
		]
	},
	{
		"gap": 0.32,
		"enemies": [
			{"position": Vector2(525.0, 225.0), "kind": "gunner", "radius": 24.0, "spawn": 0.20, "initial": 0.46, "repeat": 1.20, "score": 1050},
			{"position": Vector2(1085.0, 690.0), "kind": "gunner", "radius": 24.0, "spawn": 0.20, "initial": 0.30, "repeat": 1.24, "score": 1050}
		]
	},
	{
		"gap": 0.34,
		"enemies": [
			{"position": Vector2(805.0, 175.0), "kind": "burst", "radius": 27.0, "spawn": 0.20, "initial": 0.38, "repeat": 1.48, "score": 1250},
			{"position": Vector2(500.0, 650.0), "kind": "gunner", "radius": 23.0, "spawn": 0.20, "initial": 0.58, "repeat": 1.16, "score": 1100},
			{"position": Vector2(1110.0, 455.0), "kind": "sniper", "radius": 20.0, "spawn": 0.20, "initial": 0.34, "repeat": 1.55, "score": 1400}
		]
	},
	{
		"gap": 0.0,
		"enemies": [
			{"position": Vector2(485.0, 455.0), "kind": "burst", "radius": 25.0, "spawn": 0.18, "initial": 0.36, "repeat": 1.36, "score": 1300},
			{"position": Vector2(1080.0, 205.0), "kind": "gunner", "radius": 22.0, "spawn": 0.18, "initial": 0.42, "repeat": 1.08, "score": 1200},
			{"position": Vector2(795.0, 715.0), "kind": "sniper", "radius": 19.0, "spawn": 0.18, "initial": 0.30, "repeat": 1.44, "score": 1500},
			{"position": Vector2(1095.0, 675.0), "kind": "gunner", "radius": 22.0, "spawn": 0.18, "initial": 0.56, "repeat": 1.10, "score": 1200}
		]
	}
]

@onready var precision_objects: Node2D = %PrecisionObjects

var active_enemies: Array = []
var active_bullets: Array = []
var crosshair
var weapon_line: Line2D
var shot_line: Line2D
var wave_index := -1
var wave_delay := -1.0
var first_wave_started := false
var fire_cooldown := 0.0
var shots := 0
var hits := 0
var kills := 0
var enemy_shots := 0
var feedback_text := ""
var feedback_time := 0.0
var shot_flash_time := 0.0
var final_time := 0.0
var final_accuracy := 0.0
var final_grade := ""

func _ready() -> void:
	_build_runtime_visuals()
	super._ready()

func _build_runtime_visuals() -> void:
	crosshair = CrosshairScript.new()
	crosshair.name = "AimCrosshair"
	crosshair.z_index = 20
	precision_objects.add_child(crosshair)

	weapon_line = Line2D.new()
	weapon_line.name = "WeaponAim"
	weapon_line.width = 2.0
	weapon_line.default_color = Color(0.42, 0.92, 1.0, 0.48)
	weapon_line.antialiased = true
	weapon_line.z_index = 4
	precision_objects.add_child(weapon_line)

	shot_line = Line2D.new()
	shot_line.name = "ShotTrace"
	shot_line.width = 2.5
	shot_line.default_color = Color(1.0, 0.90, 0.58, 0.92)
	shot_line.antialiased = true
	shot_line.z_index = 15
	shot_line.visible = false
	precision_objects.add_child(shot_line)

func _reset_round(start_now: bool) -> void:
	if is_instance_valid(precision_objects):
		for child in precision_objects.get_children():
			if child == crosshair or child == weapon_line or child == shot_line:
				continue
			precision_objects.remove_child(child)
			child.queue_free()

	active_enemies.clear()
	active_bullets.clear()
	wave_index = -1
	wave_delay = -1.0
	first_wave_started = false
	fire_cooldown = 0.0
	shots = 0
	hits = 0
	kills = 0
	enemy_shots = 0
	feedback_text = ""
	feedback_time = 0.0
	shot_flash_time = 0.0
	final_time = 0.0
	final_accuracy = 0.0
	final_grade = ""

	super._reset_round(start_now)

	player.position = Vector2(800.0, 450.0)
	crosshair.position = player.position + Vector2(150.0, 0.0)
	crosshair.visible = state == "countdown"
	weapon_line.visible = state == "countdown"
	shot_line.visible = false
	_update_aim_line()
	_update_ui()

func _reset_player_position() -> void:
	player.position = Vector2(800.0, 450.0)

func _capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)

func _start_countdown() -> void:
	state = "countdown"
	countdown_left = QUICK_COUNTDOWN
	countdown_step = -1
	_hide_message_panel()
	_capture_mouse()
	tutorial_label.text = _get_countdown_tutorial_text()
	countdown_label.visible = true
	countdown_subtitle.visible = true
	countdown_label.text = "READY"
	countdown_label.add_theme_color_override("font_color", Color(0.98, 0.97, 0.93))
	countdown_subtitle.text = _get_countdown_subtitle()

func _update_countdown(delta: float) -> void:
	countdown_left = maxf(0.0, countdown_left - delta)
	if countdown_left <= 0.16:
		countdown_label.text = "GO"
		countdown_label.add_theme_color_override("font_color", Color(1.0, 0.70, 0.24))
	if countdown_left <= 0.0:
		state = "playing"
		countdown_label.visible = false
		countdown_subtitle.visible = false
		_update_level_tutorial()

func _input(event: InputEvent) -> void:
	if state == "playing" and event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_fire_weapon()
			return

	# Mouse movement now belongs only to the crosshair. Never pass it to BaseLevel,
	# because BaseLevel's normal cursor-control path would move the body as well.
	if (state == "playing" or state == "countdown") and event is InputEventMouseMotion:
		return

	super._input(event)

func _physics_process(delta: float) -> void:
	var previous_state := state
	super._physics_process(delta)

	if previous_state != "playing" and state == "playing" and not first_wave_started:
		first_wave_started = true
		_begin_wave(0)

	if state != "playing":
		return

	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	feedback_time = maxf(0.0, feedback_time - delta)
	_update_crosshair_from_mouse()

	var old_player_position := player.position
	_move_body(delta)

	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.advance(delta, player.position)

	_advance_bullets(delta, old_player_position)
	if state != "playing":
		return

	_check_enemy_contact()
	if state != "playing":
		return

	if wave_delay >= 0.0:
		wave_delay -= delta
		if wave_delay <= 0.0:
			wave_delay = -1.0
			_begin_wave(wave_index + 1)

	_update_crosshair_hot()
	_update_aim_line()
	_update_ui()

func _process(delta: float) -> void:
	super._process(delta)

	var aiming_active := state == "playing" or state == "countdown"
	if is_instance_valid(crosshair):
		crosshair.visible = aiming_active
	if is_instance_valid(weapon_line):
		weapon_line.visible = aiming_active

	if aiming_active:
		_update_crosshair_from_mouse()
		_update_crosshair_hot()
		_update_aim_line()

	if shot_flash_time > 0.0:
		shot_flash_time = maxf(0.0, shot_flash_time - delta)
		shot_line.visible = true
		shot_line.modulate.a = clampf(shot_flash_time / 0.07, 0.0, 1.0)
	else:
		shot_line.visible = false

func _move_body(delta: float) -> void:
	var input_direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	if input_direction.length_squared() > 1.0:
		input_direction = input_direction.normalized()

	var next_position := player.position + input_direction * BODY_SPEED * delta
	next_position.x = clampf(next_position.x, ARENA.position.x + BODY_RADIUS, ARENA.end.x - BODY_RADIUS)
	next_position.y = clampf(next_position.y, ARENA.position.y + BODY_RADIUS, ARENA.end.y - BODY_RADIUS)
	moved_distance += player.position.distance_to(next_position)
	player.position = next_position

func _update_crosshair_from_mouse() -> void:
	if not is_instance_valid(crosshair) or not is_instance_valid(machine_shell):
		return
	var canvas_transform := machine_shell.arena_content.get_global_transform_with_canvas()
	var local_mouse := canvas_transform.affine_inverse() * get_viewport().get_mouse_position()
	crosshair.position = Vector2(
		clampf(local_mouse.x, ARENA.position.x + 8.0, ARENA.end.x - 8.0),
		clampf(local_mouse.y, ARENA.position.y + 8.0, ARENA.end.y - 8.0)
	)

func _update_aim_line() -> void:
	if not is_instance_valid(crosshair) or not is_instance_valid(weapon_line) or not is_instance_valid(player):
		return
	var direction: Vector2 = crosshair.position - player.position
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	else:
		direction = direction.normalized()
	weapon_line.points = PackedVector2Array([
		player.position + direction * 10.0,
		player.position + direction * 34.0
	])

func _update_crosshair_hot() -> void:
	if is_instance_valid(crosshair):
		crosshair.set_hot(_enemy_under_crosshair() != null)

func _fire_weapon() -> void:
	if state != "playing" or fire_cooldown > 0.0:
		return

	fire_cooldown = FIRE_COOLDOWN
	shots += 1
	_show_shot_trace()
	shake = maxf(shake, 0.8)

	var enemy = _enemy_under_crosshair()
	if enemy == null:
		score = maxf(0.0, score - 75.0)
		_set_feedback("MISS", 0.34)
		_update_ui()
		return

	hits += 1
	kills += 1
	var reaction := float(enemy.active_age)
	var quick_bonus := maxi(0, int(round(360.0 - reaction * 180.0)))
	score += enemy.score_value + quick_bonus
	score_punch = 1.0
	_set_feedback("KILL  %dms" % int(round(reaction * 1000.0)), 0.48)
	active_enemies.erase(enemy)
	enemy.kill()
	enemy.queue_free()

	if active_enemies.is_empty():
		_on_wave_cleared()

	_update_crosshair_hot()
	_update_ui()

func _show_shot_trace() -> void:
	if not is_instance_valid(shot_line) or not is_instance_valid(crosshair):
		return
	var direction: Vector2 = crosshair.position - player.position
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	else:
		direction = direction.normalized()
	shot_line.points = PackedVector2Array([
		player.position + direction * 10.0,
		crosshair.position
	])
	shot_line.modulate.a = 1.0
	shot_line.visible = true
	shot_flash_time = 0.07

func _enemy_under_crosshair():
	if not is_instance_valid(crosshair):
		return null
	var best_enemy = null
	var best_distance := INF
	for enemy in active_enemies:
		if not is_instance_valid(enemy) or not enemy.contains_point(crosshair.position):
			continue
		var distance: float = enemy.position.distance_to(crosshair.position)
		if distance < best_distance:
			best_distance = distance
			best_enemy = enemy
	return best_enemy

func _begin_wave(index: int) -> void:
	if index < 0 or index >= WAVES.size() or state != "playing":
		return

	wave_index = index
	wave_delay = -1.0
	var wave: Dictionary = WAVES[index]
	var enemy_configs: Array = wave.get("enemies", [])
	for raw_config in enemy_configs:
		if typeof(raw_config) != TYPE_DICTIONARY:
			continue
		var config: Dictionary = raw_config
		var enemy = EnemyScript.new()
		enemy.position = config.get("position", Vector2(800.0, 300.0))
		precision_objects.add_child(enemy)
		enemy.configure(config)
		enemy.fire_requested.connect(_on_enemy_fire)
		active_enemies.append(enemy)

	_set_feedback("WAVE %d/%d" % [wave_index + 1, WAVES.size()], 0.62)
	_update_ui()

func _on_wave_cleared() -> void:
	if wave_index >= WAVES.size() - 1:
		_finish_microcombat_room()
		return

	var wave: Dictionary = WAVES[wave_index]
	wave_delay = float(wave.get("gap", 0.30))
	_set_feedback("CLEAR", minf(wave_delay, 0.28))

func _on_enemy_fire(enemy: Node2D, locked_target: Vector2, pattern: String) -> void:
	if state != "playing" or not is_instance_valid(enemy):
		return

	enemy_shots += 1
	var base_direction := locked_target - enemy.position
	if base_direction.length_squared() <= 0.001:
		base_direction = Vector2.DOWN
	else:
		base_direction = base_direction.normalized()

	match pattern:
		"burst":
			for angle_degrees in [-13.0, 0.0, 13.0]:
				_spawn_micro_bullet(enemy.position, base_direction.rotated(deg_to_rad(angle_degrees)), 345.0, 6.0, "burst")
		"sniper":
			_spawn_micro_bullet(enemy.position, base_direction, 620.0, 5.0, "sniper")
		_:
			_spawn_micro_bullet(enemy.position, base_direction, 430.0, 7.5, "gunner")

func _spawn_micro_bullet(origin: Vector2, direction: Vector2, speed: float, radius: float, style: String) -> void:
	var bullet = BulletScript.new()
	bullet.configure(origin, direction, speed, radius, style)
	projectile_layer.add_child(bullet)
	active_bullets.append(bullet)

func _advance_bullets(delta: float, old_player_position: Vector2) -> void:
	for index in range(active_bullets.size() - 1, -1, -1):
		var bullet = active_bullets[index]
		if not is_instance_valid(bullet):
			active_bullets.remove_at(index)
			continue

		bullet.advance(delta)
		if bullet.is_outside():
			active_bullets.remove_at(index)
			bullet.queue_free()
			continue

		var hit_distance := BODY_RADIUS + float(bullet.radius)
		var bullet_closest := _closest_point_on_segment(player.position, bullet.previous_position, bullet.position)
		var body_closest := _closest_point_on_segment(bullet.position, old_player_position, player.position)
		if bullet_closest.distance_to(player.position) <= hit_distance or body_closest.distance_to(bullet.position) <= hit_distance:
			_begin_death("Enemy fire")
			return

func _check_enemy_contact() -> void:
	for enemy in active_enemies:
		if not is_instance_valid(enemy) or not enemy.is_active():
			continue
		if player.position.distance_to(enemy.position) <= BODY_RADIUS + float(enemy.hit_radius) * 0.62:
			_begin_death("Enemy contact")
			return

func _finish_microcombat_room() -> void:
	final_time = elapsed
	final_accuracy = _accuracy()
	final_grade = _grade_for_result(final_time, final_accuracy)
	var speed_bonus := maxi(0, int(round(6500.0 - final_time * 260.0)))
	var accuracy_bonus := int(round(final_accuracy * 2000.0))
	score += speed_bonus + accuracy_bonus
	_win()

func _accuracy() -> float:
	if shots <= 0:
		return 0.0
	return clampf(float(hits) / float(shots), 0.0, 1.0)

func _grade_for_result(run_time: float, accuracy: float) -> String:
	if run_time <= 11.5 and accuracy >= 0.90:
		return "S"
	if run_time <= 16.0 and accuracy >= 0.78:
		return "A"
	if run_time <= 22.0 and accuracy >= 0.65:
		return "B"
	if run_time <= 30.0:
		return "C"
	return "D"

func _set_feedback(text: String, duration: float) -> void:
	feedback_text = text
	feedback_time = maxf(duration, 0.0)

func _update_ui() -> void:
	if not is_instance_valid(timer_label):
		return
	timer_label.text = _format_precise_time(elapsed)
	score_label.text = "%d/%d" % [kills, TOTAL_ENEMIES]
	var accuracy_text := "ACC --"
	if shots > 0:
		accuracy_text = "ACC %d%%" % int(round(_accuracy() * 100.0))
	if feedback_time > 0.0 and not feedback_text.is_empty():
		combo_label.text = "%s  //  %s" % [accuracy_text, feedback_text]
	else:
		combo_label.text = "%s  //  ENEMY SHOTS %d" % [accuracy_text, enemy_shots]

func _update_level_tutorial() -> void:
	if not is_instance_valid(tutorial_label):
		return
	if state == "playing":
		tutorial_label.text = "WASD MOVE  //  MOUSE AIM  //  LMB FIRE  //  ONE HIT = DEAD"
	else:
		tutorial_label.text = "MOVE THE BODY. AIM INDEPENDENTLY."

func _get_level_number() -> int:
	return 0

func _get_round_time() -> float:
	return 300.0

func _get_completion_bonus() -> float:
	return 0.0

func _get_phase() -> int:
	return 0

func _schedule_level_projectile(_current_phase: int) -> void:
	pass

func _graze_enabled_for_phase(_current_phase: int) -> bool:
	return false

func _get_intro_title() -> String:
	return "MICROCOMBAT PROTOTYPE"

func _get_intro_subtitle() -> String:
	return "DECOUPLED AIM + MOVEMENT TEST"

func _get_intro_body() -> String:
	return "WASD MOVES YOUR BODY.\nMOUSE AIMS INDEPENDENTLY. LEFT CLICK FIRES.\n\nENEMIES TELEGRAPH SHOTS BEFORE FIRING.\nORANGE = GUNNER  //  MAGENTA = BURST  //  GOLD = SNIPER\n\nONE HIT KILLS YOU. ONE HIT KILLS THEM.\nCLEAR FOUR SHORT WAVES AS FAST AND CLEAN AS POSSIBLE.\n\nR = FAST RESTART"

func _get_countdown_tutorial_text() -> String:
	return "WASD + MOUSE // SURVIVE AND SHOOT"

func _get_countdown_subtitle() -> String:
	return "MICROCOMBAT TEST"

func _get_pause_subtitle() -> String:
	return "WASD MOVE // MOUSE AIM"

func _get_death_title() -> String:
	return "RUN LOST"

func _get_death_subtitle() -> String:
	return "ONE HIT // RESET"

func _get_death_body(reason: String, run_time: float, _final_score: int, _best_score: int) -> String:
	var accuracy_value := int(round(_accuracy() * 100.0)) if shots > 0 else 0
	return "%s\n\nTIME      %s\nKILLS     %d/%d\nACCURACY  %d%%\n\nPRESS R OR CLICK TO RETRY" % [reason.to_upper(), _format_precise_time(run_time), kills, TOTAL_ENEMIES, accuracy_value]

func _get_win_title() -> String:
	return "ROOM CLEAR"

func _get_win_subtitle() -> String:
	return "GRADE %s" % final_grade

func _get_win_tutorial_text() -> String:
	return "MICROCOMBAT COMPLETE"

func _get_win_body(final_score: int, _best_score: int) -> String:
	return "TIME       %s\nACCURACY   %d%%\nENEMY FIRE %d\nGRADE      %s\nSCORE      %s\n\nCLICK OR PRESS R TO RUN IT AGAIN" % [_format_precise_time(final_time), int(round(final_accuracy * 100.0)), enemy_shots, final_grade, _format_score(final_score)]

func _format_precise_time(value: float) -> String:
	var whole := maxi(0, int(floor(value)))
	var hundredths := clampi(int(floor((value - float(whole)) * 100.0)), 0, 99)
	return "%d:%02d.%02d" % [int(whole / 60), whole % 60, hundredths]
