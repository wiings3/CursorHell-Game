extends "res://scripts/levels/base_level.gd"
class_name CursorHellPrecisionPrototype

const TargetScene := preload("res://Scenes/Components/ScoreTarget.tscn")
const LaserScene := preload("res://Scenes/Components/RouteLaser.tscn")

# This prototype tests the intended FPS-adjacent hand rhythm:
# acquire -> flick -> click -> evade -> reacquire.
# Targets vary in distance, size, lifetime and priority. Hazards exist to disrupt
# the shot rather than becoming the objective themselves.
const WAVES := [
	{
		"gap": 0.20,
		"targets": [
			{"position": Vector2(1080.0, 450.0), "radius": 38.0, "lifetime": 2.40, "label": "ACQUIRE", "kind": "normal", "score": 800}
		]
	},
	{
		"gap": 0.14,
		"targets": [
			{"position": Vector2(510.0, 220.0), "radius": 28.0, "lifetime": 1.20, "label": "SNAP", "kind": "normal", "score": 950}
		]
	},
	{
		"gap": 0.16,
		"targets": [
			{"position": Vector2(565.0, 270.0), "radius": 15.0, "lifetime": 0.86, "label": "MICRO", "kind": "precision", "score": 1250}
		]
	},
	{
		"gap": 0.12,
		"targets": [
			{"position": Vector2(1100.0, 715.0), "radius": 24.0, "lifetime": 0.96, "label": "SWITCH", "kind": "normal", "score": 1050}
		]
	},
	{
		"gap": 0.16,
		"targets": [
			{"position": Vector2(520.0, 540.0), "radius": 22.0, "lifetime": 0.72, "label": "THREAT", "kind": "threat", "score": 1300}
		]
	},
	{
		"gap": 0.12,
		"hazards": [
			{"orientation": "vertical", "coordinate": 820.0, "charge": 0.46, "lethal": 1.45, "width": 20.0}
		],
		"targets": [
			{"position": Vector2(1090.0, 190.0), "radius": 22.0, "lifetime": 1.18, "label": "CROSS", "kind": "normal", "score": 1200}
		]
	},
	{
		"gap": 0.10,
		"hazards": [
			{"orientation": "horizontal", "coordinate": 760.0, "charge": 0.38, "lethal": 1.85, "width": 20.0, "sweep_from": 760.0, "sweep_to": 180.0}
		],
		"targets": [
			{"position": Vector2(525.0, 700.0), "radius": 20.0, "lifetime": 1.05, "label": "TRACK", "kind": "normal", "score": 1250}
		]
	},
	{
		"gap": 0.12,
		"targets": [
			{"position": Vector2(1105.0, 470.0), "radius": 18.0, "lifetime": 0.84, "label": "REACQUIRE", "kind": "precision", "score": 1400}
		]
	},
	{
		"gap": 0.18,
		"targets": [
			{"position": Vector2(505.0, 205.0), "radius": 19.0, "lifetime": 0.60, "label": "FAST", "kind": "threat", "score": 1550},
			{"position": Vector2(1085.0, 690.0), "radius": 25.0, "lifetime": 1.34, "label": "HOLD", "kind": "normal", "score": 1050}
		]
	},
	{
		"gap": 0.12,
		"hazards": [
			{"orientation": "horizontal", "coordinate": 430.0, "charge": 0.36, "lethal": 1.35, "width": 18.0}
		],
		"targets": [
			{"position": Vector2(805.0, 575.0), "radius": 12.0, "lifetime": 0.98, "label": "PRECISION", "kind": "precision", "score": 1800}
		]
	},
	{
		"gap": 0.08,
		"targets": [
			{"position": Vector2(480.0, 185.0), "radius": 20.0, "lifetime": 0.72, "label": "1", "kind": "normal", "score": 1400}
		]
	},
	{
		"gap": 0.07,
		"targets": [
			{"position": Vector2(1130.0, 710.0), "radius": 18.0, "lifetime": 0.64, "label": "2", "kind": "normal", "score": 1500}
		]
	},
	{
		"gap": 0.06,
		"hazards": [
			{"orientation": "vertical", "coordinate": 925.0, "charge": 0.34, "lethal": 1.35, "width": 18.0},
			{"orientation": "horizontal", "coordinate": 560.0, "charge": 0.54, "lethal": 1.30, "width": 18.0}
		],
		"targets": [
			{"position": Vector2(800.0, 235.0), "radius": 14.0, "lifetime": 0.60, "label": "3", "kind": "threat", "score": 1900}
		]
	}
]

@onready var precision_objects: Node2D = %PrecisionObjects

var wave_index := 0
var active_targets: Array[CursorHellScoreTarget] = []
var active_lasers: Array[CursorHellRouteLaser] = []
var first_wave_started := false
var pending_wave_delay := -1.0
var hits := 0
var target_misses := 0
var shot_misses := 0
var perfects := 0
var reaction_samples: Array[float] = []
var feedback_text := ""
var feedback_time := 0.0
var final_time := 0.0
var final_grade := ""

func _reset_round(start_now: bool) -> void:
	if is_instance_valid(precision_objects):
		for child in precision_objects.get_children():
			precision_objects.remove_child(child)
			child.queue_free()
	wave_index = 0
	active_targets.clear()
	active_lasers.clear()
	first_wave_started = false
	pending_wave_delay = -1.0
	hits = 0
	target_misses = 0
	shot_misses = 0
	perfects = 0
	reaction_samples.clear()
	feedback_text = ""
	feedback_time = 0.0
	final_time = 0.0
	final_grade = ""
	super._reset_round(start_now)
	_update_ui()

func _reset_player_position() -> void:
	player.position = Vector2(800.0, 450.0)

func _input(event: InputEvent) -> void:
	if state == "playing" and event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			var target := _target_under_cursor()
			if is_instance_valid(target):
				_hit_target(target)
			else:
				shot_misses += 1
				score = maxf(0.0, score - 125.0)
				_set_feedback("MISS", 0.46)
			_update_ui()
			return

	var old_position := player.position if is_instance_valid(player) else Vector2.ZERO
	super._input(event)

	if state == "playing" and event is InputEventMouseMotion and is_instance_valid(player):
		for laser in active_lasers:
			if is_instance_valid(laser) and laser.intersects_segment(old_position, player.position):
				_begin_death("Laser contact")
				return

func _physics_process(delta: float) -> void:
	var previous_state := state
	super._physics_process(delta)

	if previous_state != "playing" and state == "playing" and not first_wave_started:
		first_wave_started = true
		_spawn_wave(0)

	if state != "playing":
		return

	feedback_time = maxf(0.0, feedback_time - delta)

	if pending_wave_delay >= 0.0:
		pending_wave_delay -= delta
		if pending_wave_delay <= 0.0:
			pending_wave_delay = -1.0
			_spawn_wave(wave_index)

	for index in range(active_lasers.size() - 1, -1, -1):
		var laser := active_lasers[index]
		if not is_instance_valid(laser):
			active_lasers.remove_at(index)
			continue
		if laser.state == "spent":
			active_lasers.remove_at(index)
			laser.queue_free()
			continue
		if laser.contains_point(player.position):
			_begin_death("Laser contact")
			return

	_update_ui()

func _target_under_cursor() -> CursorHellScoreTarget:
	if not is_instance_valid(player):
		return null
	var best_target: CursorHellScoreTarget = null
	var best_distance := INF
	for target in active_targets:
		if not is_instance_valid(target) or target.consumed:
			continue
		var distance := target.global_position.distance_to(player.global_position)
		if distance <= target.hit_radius and distance < best_distance:
			best_distance = distance
			best_target = target
	return best_target

func _spawn_wave(index: int) -> void:
	if index < 0 or index >= WAVES.size() or state != "playing":
		return
	var wave: Dictionary = WAVES[index]
	_spawn_wave_hazards(wave)

	var target_configs: Array = wave.get("targets", [])
	for raw_target in target_configs:
		if typeof(raw_target) != TYPE_DICTIONARY:
			continue
		var target_config: Dictionary = raw_target
		_spawn_precision_target(target_config)

	_update_level_tutorial()

func _spawn_wave_hazards(wave: Dictionary) -> void:
	var hazard_configs: Array = wave.get("hazards", [])
	for raw_hazard in hazard_configs:
		if typeof(raw_hazard) != TYPE_DICTIONARY:
			continue
		_spawn_laser(raw_hazard as Dictionary)

func _spawn_precision_target(config: Dictionary) -> void:
	var target := TargetScene.instantiate() as CursorHellScoreTarget
	if target == null:
		return

	target.set_meta("suppress_score_target_tutorial", true)
	target.set_meta("precision_kind", str(config.get("kind", "normal")))
	target.set_meta("precision_wave", wave_index)
	precision_objects.add_child(target)
	target.position = config.get("position", Vector2(800.0, 450.0)) as Vector2
	target.hit_radius = float(config.get("radius", 30.0))
	var lifetime := float(config.get("lifetime", 1.0))
	var target_score := int(config.get("score", 1000))
	target.configure_chain(1, 1, lifetime, target.hit_radius, target_score)
	target.expired.connect(_on_target_expired)
	if is_instance_valid(target.purge_ring):
		target.purge_ring.visible = false

	var visual_scale := clampf(target.hit_radius / 30.0, 0.38, 1.30)
	target.scale = Vector2.ONE * visual_scale
	if is_instance_valid(target.stage_label):
		target.stage_label.text = str(config.get("label", "HIT"))
		target.stage_label.scale = Vector2.ONE / visual_scale
	_style_target(target, str(config.get("kind", "normal")))
	active_targets.append(target)

func _style_target(target: CursorHellScoreTarget, kind: String) -> void:
	if not is_instance_valid(target):
		return
	var ring_color := Color(0.20, 0.92, 1.0, 0.96)
	var core_color := Color(0.74, 1.0, 1.0, 0.98)
	if kind == "precision":
		ring_color = Color(0.72, 0.82, 1.0, 0.98)
		core_color = Color(0.96, 0.98, 1.0, 1.0)
	elif kind == "threat":
		ring_color = Color(1.0, 0.36, 0.10, 0.98)
		core_color = Color(1.0, 0.82, 0.30, 1.0)

	target.outer_ring.default_color = ring_color
	target.core.color = core_color
	target.cross_h.default_color = core_color
	target.cross_v.default_color = core_color
	if is_instance_valid(target.stage_label):
		target.stage_label.add_theme_color_override("font_color", core_color)

func _hit_target(target: CursorHellScoreTarget) -> void:
	if not is_instance_valid(target):
		return
	var reaction := maxf(target.age, 0.0)
	var distance := target.global_position.distance_to(player.global_position)
	var perfect := distance <= target.hit_radius * 0.32
	var lifetime := maxf(target.lifetime, 0.001)
	var speed_ratio := clampf(1.0 - reaction / lifetime, 0.0, 1.0)
	var bonus := target.score_bonus + int(round(speed_ratio * 500.0))
	if perfect:
		bonus += 350
		perfects += 1

	hits += 1
	reaction_samples.append(reaction)
	score += bonus
	score_punch = 1.0
	active_targets.erase(target)
	_set_feedback("%s  %dms" % ["PERFECT" if perfect else "HIT", int(round(reaction * 1000.0))], 0.62)
	target.consume()

	if active_targets.is_empty():
		_finish_wave()

func _on_target_expired(target: CursorHellScoreTarget) -> void:
	active_targets.erase(target)
	if state != "playing":
		return

	target_misses += 1
	score = maxf(0.0, score - 300.0)
	var kind := str(target.get_meta("precision_kind", "normal"))
	if kind == "threat":
		_set_feedback("LATE  //  THREAT FIRED", 0.80)
		_fire_reaction_laser()
	else:
		_set_feedback("LATE", 0.62)

	if active_targets.is_empty():
		_finish_wave()

func _finish_wave() -> void:
	if wave_index >= WAVES.size() - 1:
		_finish_precision_test()
		return

	var completed_wave: Dictionary = WAVES[wave_index]
	wave_index += 1
	pending_wave_delay = float(completed_wave.get("gap", 0.12))

func _spawn_laser(config: Dictionary) -> void:
	var laser := LaserScene.instantiate() as CursorHellRouteLaser
	if laser == null:
		return
	precision_objects.add_child(laser)
	laser.configure(
		str(config.get("orientation", "vertical")),
		float(config.get("coordinate", 800.0)),
		float(config.get("charge", 0.45)),
		float(config.get("lethal", 1.35)),
		float(config.get("width", 20.0))
	)
	if config.has("sweep_from") and config.has("sweep_to"):
		laser.configure_sweep(float(config["sweep_from"]), float(config["sweep_to"]))
	active_lasers.append(laser)
	laser.prime()

func _fire_reaction_laser() -> void:
	if not is_instance_valid(player):
		return
	var horizontal := wave_index % 2 == 0
	var config := {
		"orientation": "horizontal" if horizontal else "vertical",
		"coordinate": player.position.y if horizontal else player.position.x,
		"charge": 0.18,
		"lethal": 1.05,
		"width": 18.0
	}
	_spawn_laser(config)

func _finish_precision_test() -> void:
	if state != "playing":
		return
	final_time = elapsed
	final_grade = _grade_run()
	var time_bonus := maxi(0, int(round(18000.0 - final_time * 650.0)))
	score += time_bonus
	_win()

func _set_feedback(text: String, duration: float) -> void:
	feedback_text = text
	feedback_time = maxf(duration, 0.0)

func _update_ui() -> void:
	if not is_instance_valid(timer_label):
		return
	var whole := int(floor(elapsed))
	var hundredths := int(floor((elapsed - float(whole)) * 100.0))
	timer_label.text = "%d:%02d.%02d" % [int(whole / 60), whole % 60, hundredths]
	score_label.text = _format_score(int(score))
	if feedback_time > 0.0:
		combo_label.text = feedback_text
	else:
		combo_label.text = "HIT %02d  //  TARGET MISS %02d  //  SHOT MISS %02d" % [hits, target_misses, shot_misses]

func _update_level_tutorial() -> void:
	if not is_instance_valid(tutorial_label):
		return
	if state == "playing":
		tutorial_label.text = "PRECISION TEST  //  WAVE %02d/%02d  //  ACQUIRE  FLICK  CLICK" % [wave_index + 1, WAVES.size()]
	else:
		tutorial_label.text = "REACTION + PRECISION"

func _get_level_number() -> int:
	return 0

func _get_round_time() -> float:
	return 120.0

func _get_phase() -> int:
	return 0

func _schedule_level_projectile(_current_phase: int) -> void:
	pass

func _get_intro_title() -> String:
	return "PRECISION PROTOTYPE"

func _get_intro_subtitle() -> String:
	return "REACTION // FLICK // TARGET SWITCHING"

func _get_intro_body() -> String:
	return "THIS TEST IS ABOUT MOUSE EXECUTION, NOT SURVIVAL.\n\nACQUIRE THE ACTIVE TARGET, FLICK TO IT, AND CLICK.\nSMALL TARGETS TEST PRECISION. ORANGE THREATS PUNISH SLOW REACTIONS.\n\nMISSED THREATS FIRE BACK. LASERS FORCE YOU TO REACQUIRE WHILE MOVING.\n\nCLEAR THE SEQUENCE AS QUICKLY AND CLEANLY AS POSSIBLE."

func _get_countdown_tutorial_text() -> String:
	return "GET READY // FIND IT AND CLICK"

func _get_countdown_subtitle() -> String:
	return "PRECISION TEST"

func _get_death_title() -> String:
	return "EXECUTION FAILED"

func _get_death_subtitle() -> String:
	return "PRECISION TEST // IMPACT"

func _get_death_body(reason: String, run_time: float, _final_score: int, _best_score: int) -> String:
	return "%s\n\nTIME          %s\nHITS          %d\nTARGET MISSES %d\nSHOT MISSES   %d\nPERFECTS      %d\nAVG REACTION  %dms\n\nCLICK OR PRESS R TO RETRY" % [
		reason.to_upper(),
		_format_precise_time(run_time),
		hits,
		target_misses,
		shot_misses,
		perfects,
		_average_reaction_ms()
	]

func _get_win_title() -> String:
	return "TEST COMPLETE"

func _get_win_subtitle() -> String:
	return "GRADE %s" % final_grade

func _get_win_tutorial_text() -> String:
	return "PRECISION TEST COMPLETE"

func _get_win_body(final_score: int, _best_score: int) -> String:
	return "TIME          %s\nHITS          %d / %d\nTARGET MISSES %d\nSHOT MISSES   %d\nPERFECTS      %d\nAVG REACTION  %dms\nSCORE         %s\nGRADE         %s\n\nCLICK OR PRESS R TO PLAY AGAIN" % [
		_format_precise_time(final_time),
		hits,
		_total_target_count(),
		target_misses,
		shot_misses,
		perfects,
		_average_reaction_ms(),
		_format_score(final_score),
		final_grade
	]

func _grade_run() -> String:
	if target_misses == 0 and shot_misses == 0 and final_time <= 11.5:
		return "S"
	if target_misses <= 1 and shot_misses <= 2 and final_time <= 15.0:
		return "A"
	if target_misses <= 2 and shot_misses <= 4 and final_time <= 20.0:
		return "B"
	if hits >= int(ceil(float(_total_target_count()) * 0.70)):
		return "C"
	return "D"

func _average_reaction_ms() -> int:
	if reaction_samples.is_empty():
		return 0
	var total := 0.0
	for value in reaction_samples:
		total += value
	return int(round((total / float(reaction_samples.size())) * 1000.0))

func _total_target_count() -> int:
	var total := 0
	for raw_wave in WAVES:
		var wave: Dictionary = raw_wave
		var targets: Array = wave.get("targets", [])
		total += targets.size()
	return total

func _format_precise_time(value: float) -> String:
	var whole := maxi(0, int(floor(value)))
	var hundredths := clampi(int(floor((value - float(whole)) * 100.0)), 0, 99)
	return "%d:%02d.%02d" % [int(whole / 60), whole % 60, hundredths]
