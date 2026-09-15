extends "res://scripts/levels/base_level.gd"
class_name CursorHellRoutePrototype

const TargetScene := preload("res://Scenes/Components/ScoreTarget.tscn")
const LaserScene := preload("res://Scenes/Components/RouteLaser.tscn")

const TARGET_POSITIONS := [
	Vector2(1040.0, 270.0),
	Vector2(620.0, 690.0),
	Vector2(1060.0, 650.0)
]

const LASER_CONFIGS := [
	{"orientation": "vertical", "coordinate": 780.0},
	{"orientation": "horizontal", "coordinate": 500.0},
	{"orientation": "vertical", "coordinate": 860.0}
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
	player.position = Vector2(510.0, 450.0)

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
		_prime_laser(0)

	if state != "playing":
		return

	for laser in route_lasers:
		if is_instance_valid(laser) and laser.contains_point(player.position):
			_begin_death("Laser contact")
			return

func _spawn_route_lasers() -> void:
	for config in LASER_CONFIGS:
		var laser := LaserScene.instantiate() as CursorHellRouteLaser
		if laser == null:
			continue
		route_objects.add_child(laser)
		laser.configure(
			str(config.get("orientation", "vertical")),
			float(config.get("coordinate", 800.0)),
			1.05,
			1.20,
			22.0
		)
		route_lasers.append(laser)

func _spawn_target(index: int) -> void:
	if index < 0 or index >= TARGET_POSITIONS.size():
		return
	var target := TargetScene.instantiate() as CursorHellScoreTarget
	if target == null:
		return
	# Route targets reuse the score-target visual, but they are mandatory route
	# objectives, not the optional Endless chain mechanic. Prevent the legacy
	# first-time chain tutorial from intercepting this mode.
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
		var speed_bonus := maxi(0, int(round(12000.0 - final_time * 700.0)))
		score += speed_bonus
		_win()
		return

	_spawn_target(current_target_index)
	_prime_laser(current_target_index)
	_update_ui()

func _prime_laser(index: int) -> void:
	if index < 0 or index >= route_lasers.size():
		return
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
		tutorial_label.text = "TARGET %d/%d  //  CLICK IT  //  BEAT THE LASER OR WAIT IT OUT" % [current_target_index + 1, TARGET_POSITIONS.size()]
	else:
		tutorial_label.text = "CLICK TARGETS IN ORDER"

func _get_level_number() -> int:
	return 0

func _get_round_time() -> float:
	return 300.0

func _get_phase() -> int:
	return 0

func _schedule_level_projectile(_current_phase: int) -> void:
	pass

func _get_intro_title() -> String:
	return "ROUTE PROTOTYPE"

func _get_intro_subtitle() -> String:
	return "TARGET ROUTING // LASER TEST"

func _get_intro_body() -> String:
	return "MOVE TO THE ACTIVE TARGET AND CLICK IT.\n\nEACH TARGET ARMS THE NEXT LASER.\n\nCROSS BEFORE IT FIRES OR WAIT FOR IT TO BURN OUT.\n\nTHIS TEST IS ABOUT MOVEMENT, ROUTING, AND RISK."

func _get_countdown_tutorial_text() -> String:
	return "GET READY // TARGET 1"

func _get_countdown_subtitle() -> String:
	return "ROUTE TEST"

func _get_death_title() -> String:
	return "ROUTE FAILED"

func _get_death_subtitle() -> String:
	return "LASER CONTACT"

func _get_death_body(reason: String, run_time: float, _final_score: int, _best_score: int) -> String:
	return "%s\n\nTIME   %s\nTARGET %d/%d\n\nCLICK OR PRESS R TO RETRY" % [reason.to_upper(), _format_precise_time(run_time), current_target_index + 1, TARGET_POSITIONS.size()]

func _get_win_title() -> String:
	return "ROUTE COMPLETE"

func _get_win_subtitle() -> String:
	return "GRADE %s" % final_grade

func _get_win_tutorial_text() -> String:
	return "ROUTE COMPLETE"

func _get_win_body(final_score: int, _best_score: int) -> String:
	return "TIME    %s\nGRADE   %s\nSCORE   %s\n\nCLICK OR PRESS R TO PLAY AGAIN" % [_format_precise_time(final_time), final_grade, _format_score(final_score)]

func _grade_for_time(value: float) -> String:
	if value <= 5.5:
		return "S"
	if value <= 7.0:
		return "A"
	if value <= 9.0:
		return "B"
	if value <= 12.0:
		return "C"
	return "D"

func _format_precise_time(value: float) -> String:
	var whole := maxi(0, int(floor(value)))
	var hundredths := clampi(int(floor((value - float(whole)) * 100.0)), 0, 99)
	return "%d:%02d.%02d" % [int(whole / 60), whole % 60, hundredths]
