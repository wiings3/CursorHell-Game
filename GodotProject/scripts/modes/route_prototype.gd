extends "res://scripts/levels/base_level.gd"
class_name CursorHellRoutePrototype

const TargetScene := preload("res://Scenes/Components/ScoreTarget.tscn")
const LaserScene := preload("res://Scenes/Components/RouteLaser.tscn")

const TARGET_POSITIONS := [
	Vector2(1090.0, 170.0),
	Vector2(520.0, 730.0),
	Vector2(1110.0, 680.0),
	Vector2(610.0, 170.0),
	Vector2(1110.0, 320.0),
	Vector2(500.0, 640.0),
	Vector2(1120.0, 190.0),
	Vector2(690.0, 760.0),
	Vector2(1100.0, 520.0),
	Vector2(520.0, 260.0)
]

# Each hazard belongs to the target stage that is currently active. Stage 0 is
# armed when the run begins. Clicking target N immediately arms stage N while
# the next target appears, so fast play can overlap hazards from consecutive
# stages instead of waiting for the arena to become completely safe.
const HAZARD_CONFIGS := [
	{"stage": 0, "orientation": "vertical", "coordinate": 790.0, "charge": 0.58, "lethal": 1.55, "width": 22.0},
	{"stage": 1, "orientation": "horizontal", "coordinate": 500.0, "charge": 0.52, "lethal": 1.65, "width": 22.0},
	{"stage": 2, "orientation": "vertical", "coordinate": 1120.0, "charge": 0.46, "lethal": 2.25, "width": 20.0, "sweep_from": 1120.0, "sweep_to": 520.0},
	{"stage": 3, "orientation": "horizontal", "coordinate": 430.0, "charge": 0.48, "lethal": 1.75, "width": 24.0},
	{"stage": 4, "orientation": "vertical", "coordinate": 850.0, "charge": 0.50, "lethal": 1.85, "width": 22.0},
	{"stage": 4, "orientation": "horizontal", "coordinate": 260.0, "charge": 0.68, "lethal": 1.65, "width": 20.0},
	{"stage": 5, "orientation": "horizontal", "coordinate": 760.0, "charge": 0.42, "lethal": 2.35, "width": 20.0, "sweep_from": 760.0, "sweep_to": 180.0},
	{"stage": 6, "orientation": "vertical", "coordinate": 720.0, "charge": 0.40, "lethal": 1.90, "width": 24.0},
	{"stage": 7, "orientation": "horizontal", "coordinate": 470.0, "charge": 0.46, "lethal": 2.00, "width": 22.0},
	{"stage": 7, "orientation": "vertical", "coordinate": 930.0, "charge": 0.72, "lethal": 1.75, "width": 20.0},
	{"stage": 8, "orientation": "vertical", "coordinate": 460.0, "charge": 0.38, "lethal": 2.30, "width": 20.0, "sweep_from": 460.0, "sweep_to": 1150.0},
	{"stage": 9, "orientation": "vertical", "coordinate": 820.0, "charge": 0.42, "lethal": 2.00, "width": 22.0},
	{"stage": 9, "orientation": "horizontal", "coordinate": 420.0, "charge": 0.64, "lethal": 1.85, "width": 20.0}
]

@onready var route_objects: Node2D = %RouteObjects

var current_target_index := 0
var active_target: CursorHellScoreTarget
var route_lasers: Array[CursorHellRouteLaser] = []
var first_hazard_armed := false
var final_time := 0.0
var final_grade := ""

func _reset_round(start_now: bool) -> void:
	if is_instance_valid(route_objects):
		for child in route_objects.get_children():
			child.queue_free()
	current_target_index = 0
	active_target = null
	route_lasers.clear()
	first_hazard_armed = false
	final_time = 0.0
	final_grade = ""
	super._reset_round(start_now)
	_spawn_route_lasers()
	_spawn_target(current_target_index)
	_update_ui()

func _reset_player_position() -> void:
	player.position = Vector2(500.0, 450.0)

func _input(event: InputEvent) -> void:
	if state == "playing" and event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			if is_instance_valid(active_target) and active_target.contains_point(player.global_position):
				_hit_active_target()
				return

	var old_position := player.position if is_instance_valid(player) else Vector2.ZERO
	super._input(event)

	if state == "playing" and event is InputEventMouseMotion and is_instance_valid(player):
		for laser in route_lasers:
			if is_instance_valid(laser) and laser.intersects_segment(old_position, player.position):
				_begin_death("Laser contact")
				return

func _physics_process(delta: float) -> void:
	var previous_state := state
	super._physics_process(delta)

	if previous_state != "playing" and state == "playing" and not first_hazard_armed:
		first_hazard_armed = true
		_prime_stage(0)

	if state != "playing":
		return

	for laser in route_lasers:
		if is_instance_valid(laser) and laser.contains_point(player.position):
			_begin_death("Laser contact")
			return

func _spawn_route_lasers() -> void:
	for config in HAZARD_CONFIGS:
		var laser := LaserScene.instantiate() as CursorHellRouteLaser
		if laser == null:
			continue
		route_objects.add_child(laser)
		laser.configure(
			str(config.get("orientation", "vertical")),
			float(config.get("coordinate", 800.0)),
			float(config.get("charge", 0.50)),
			float(config.get("lethal", 1.80)),
			float(config.get("width", 22.0))
		)
		if config.has("sweep_from") and config.has("sweep_to"):
			laser.configure_sweep(float(config["sweep_from"]), float(config["sweep_to"]))
		route_lasers.append(laser)

func _spawn_target(index: int) -> void:
	if index < 0 or index >= TARGET_POSITIONS.size():
		return
	var target := TargetScene.instantiate() as CursorHellScoreTarget
	if target == null:
		return
	# Route targets reuse the score-target visual, but they are mandatory route
	# objectives, not the optional Endless chain mechanic.
	target.set_meta("suppress_score_target_tutorial", true)
	route_objects.add_child(target)
	target.position = TARGET_POSITIONS[index]
	target.configure_chain(index + 1, TARGET_POSITIONS.size(), 999.0, 30.0, 1000)
	if is_instance_valid(target.purge_ring):
		target.purge_ring.visible = false
	active_target = target
	_update_level_tutorial()

func _hit_active_target() -> void:
	if not is_instance_valid(active_target):
		return

	active_target.consume()
	active_target = null
	score += 1000.0
	current_target_index += 1

	if current_target_index >= TARGET_POSITIONS.size():
		final_time = elapsed
		final_grade = _grade_for_time(final_time)
		var speed_bonus := maxi(0, int(round(30000.0 - final_time * 1100.0)))
		score += speed_bonus
		_win()
		return

	_spawn_target(current_target_index)
	_prime_stage(current_target_index)
	_update_ui()

func _prime_stage(stage: int) -> void:
	for index in range(mini(route_lasers.size(), HAZARD_CONFIGS.size())):
		if int(HAZARD_CONFIGS[index].get("stage", -1)) != stage:
			continue
		var laser := route_lasers[index]
		if is_instance_valid(laser):
			laser.prime()

func _update_ui() -> void:
	if not is_instance_valid(timer_label):
		return
	var whole := int(floor(elapsed))
	var hundredths := int(floor((elapsed - float(whole)) * 100.0))
	timer_label.text = "%d:%02d.%02d" % [int(whole / 60), whole % 60, hundredths]
	score_label.text = "%d/%d" % [mini(current_target_index, TARGET_POSITIONS.size()), TARGET_POSITIONS.size()]
	combo_label.text = ""

func _update_level_tutorial() -> void:
	if not is_instance_valid(tutorial_label):
		return
	if state == "playing":
		tutorial_label.text = "TARGET %d/%d  //  KEEP MOVING  //  RUSH THE CHARGE OR WAIT FOR THE BURNOUT" % [current_target_index + 1, TARGET_POSITIONS.size()]
	else:
		tutorial_label.text = "10 TARGET ROUTE TEST"

func _get_level_number() -> int:
	return 0

func _get_round_time() -> float:
	return 300.0

func _get_phase() -> int:
	return 0

func _schedule_level_projectile(_current_phase: int) -> void:
	pass

func _get_intro_title() -> String:
	return "ROUTE TEST 01"

func _get_intro_subtitle() -> String:
	return "10 TARGETS // ESCALATING LASER COURSE"

func _get_intro_body() -> String:
	return "CLEAR ALL 10 TARGETS AS FAST AS POSSIBLE.\n\nEVERY TARGET ARMS THE NEXT HAZARD. FAST PLAY CAN LEAVE MULTIPLE LASERS ACTIVE AT ONCE.\n\nSTATIC GATES BLOCK ROUTES. SWEEPING BEAMS CHASE ACROSS THE ARENA.\n\nRUSH A CHARGING BEAM TO SAVE TIME, OR WAIT FOR IT TO BURN OUT AND TAKE THE SAFE ROUTE."

func _get_countdown_tutorial_text() -> String:
	return "GET READY // 10 TARGETS"

func _get_countdown_subtitle() -> String:
	return "ROUTE TEST 01"

func _get_death_title() -> String:
	return "ROUTE FAILED"

func _get_death_subtitle() -> String:
	return "LASER CONTACT"

func _get_death_body(reason: String, run_time: float, _final_score: int, _best_score: int) -> String:
	return "%s\n\nTIME   %s\nTARGET %d/%d\n\nCLICK OR PRESS R TO RETRY" % [reason.to_upper(), _format_precise_time(run_time), mini(current_target_index + 1, TARGET_POSITIONS.size()), TARGET_POSITIONS.size()]

func _get_win_title() -> String:
	return "ROUTE COMPLETE"

func _get_win_subtitle() -> String:
	return "GRADE %s" % final_grade

func _get_win_tutorial_text() -> String:
	return "ROUTE COMPLETE"

func _get_win_body(final_score: int, _best_score: int) -> String:
	return "TIME    %s\nGRADE   %s\nSCORE   %s\n\nCLICK OR PRESS R TO PLAY AGAIN" % [_format_precise_time(final_time), final_grade, _format_score(final_score)]

func _grade_for_time(value: float) -> String:
	if value <= 7.0:
		return "S"
	if value <= 10.0:
		return "A"
	if value <= 14.0:
		return "B"
	if value <= 19.0:
		return "C"
	return "D"

func _format_precise_time(value: float) -> String:
	var whole := maxi(0, int(floor(value)))
	var hundredths := clampi(int(floor((value - float(whole)) * 100.0)), 0, 99)
	return "%d:%02d.%02d" % [int(whole / 60), whole % 60, hundredths]
