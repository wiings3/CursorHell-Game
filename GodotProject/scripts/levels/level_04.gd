extends "res://scripts/levels/standard_dodge_level.gd"
class_name CursorHellLevel04

const ROUND_TIME := 60.0
const COMPLETION_BONUS := 4000.0
const WALL_SLOT_COUNT := 21
const WALL_LANE_MIN := 0.05
const WALL_LANE_MAX := 0.95

var gap_attack_index := 0
var gap_phase := -1
var last_gap_lane := -1.0

func _reset_round(start_now: bool) -> void:
	gap_attack_index = 0
	gap_phase = -1
	last_gap_lane = -1.0
	super._reset_round(start_now)

func _get_level_number() -> int:
	return 4

func _get_round_time() -> float:
	return ROUND_TIME

func _get_completion_bonus() -> float:
	return COMPLETION_BONUS

func _get_phase() -> int:
	if elapsed < 5.0:
		return 0
	if elapsed < 13.0:
		return 1
	if elapsed < 23.0:
		return 2
	if elapsed < 35.0:
		return 3
	if elapsed < 48.0:
		return 4
	return 5

func _update_level_tutorial() -> void:
	match _get_phase():
		0:
			tutorial_label.text = "THE GAP\nA wall is coming. Find the missing section."
		1:
			tutorial_label.text = "FIND THE OPENING\nMove into the gap before the wall reaches you."
		2:
			tutorial_label.text = "COMMIT EARLY\nThe opening is smaller and can arrive from either side."
		3:
			tutorial_label.text = "EVERY EDGE\nFind the safe lane before the wall crosses the arena."
		4:
			tutorial_label.text = "PRESSURE RHYTHM\nSingle and double walls now mix. Keep reading."
		_:
			tutorial_label.text = "NO RESET\nFaster walls. Smaller openings. Commit immediately."

func _schedule_level_projectile(current_phase: int) -> void:
	# Reset the local attack rhythm at each phase transition so every lesson begins
	# with a deliberate pattern rather than inheriting parity from the last one.
	if current_phase != gap_phase:
		gap_phase = current_phase
		gap_attack_index = 0
		last_gap_lane = -1.0
	gap_attack_index += 1

	match current_phase:
		1:
			# Teach the rule quickly: one readable wall from a consistent edge.
			var phase1_gap: float = _choose_gap_lane(0.18)
			_queue_gap_wall(0, phase1_gap, 0.075, 205.0, 1.20)
		2:
			# Alternate left and right with a tighter opening and a clear speed jump.
			var phase2_side: int = 0 if gap_attack_index % 2 == 1 else 1
			var phase2_gap: float = _choose_gap_lane(0.22)
			_queue_gap_wall(phase2_side, phase2_gap, 0.060, 220.0, 1.08)
		3:
			# Carry the same safe-gap read around all four edges. This is the final
			# practice phase before double-wall pressure becomes normal gameplay.
			var phase3_sides: Array[int] = [0, 2, 1, 3]
			var phase3_side: int = phase3_sides[(gap_attack_index - 1) % phase3_sides.size()]
			var phase3_gap: float = _choose_gap_lane(0.22)
			_queue_gap_wall(phase3_side, phase3_gap, 0.050, 235.0, 0.96)
		4:
			_queue_pressure_attack()
		_:
			_queue_final_attack()

func _queue_pressure_attack() -> void:
	# The hard state starts at 35 seconds and stays active long enough to become
	# the level's main gameplay. Lower-pressure single walls are mixed between
	# double walls so the rhythm breathes without dropping back to tutorial play.
	var pattern: int = (gap_attack_index - 1) % 4

	if pattern == 0:
		var pressure_horizontal_gap: float = _choose_gap_lane(0.24)
		var pressure_vertical_gap: float = rng.randf_range(0.18, 0.82)
		_queue_gap_wall(0, pressure_horizontal_gap, 0.045, 245.0, 0.90)
		_queue_gap_wall(2, pressure_vertical_gap, 0.045, 245.0, 1.55)
	elif pattern == 1:
		var pressure_vertical_side: int = 2 if gap_attack_index % 2 == 0 else 3
		var pressure_single_vertical_gap: float = _choose_gap_lane(0.24)
		_queue_gap_wall(pressure_vertical_side, pressure_single_vertical_gap, 0.050, 245.0, 0.90)
	elif pattern == 2:
		var pressure_horizontal_gap_b: float = _choose_gap_lane(0.24)
		var pressure_vertical_gap_b: float = rng.randf_range(0.18, 0.82)
		_queue_gap_wall(1, pressure_horizontal_gap_b, 0.045, 245.0, 0.88)
		_queue_gap_wall(3, pressure_vertical_gap_b, 0.045, 245.0, 1.48)
	else:
		var pressure_horizontal_side: int = 0 if gap_attack_index % 2 == 1 else 1
		var pressure_single_horizontal_gap: float = _choose_gap_lane(0.24)
		_queue_gap_wall(pressure_horizontal_side, pressure_single_horizontal_gap, 0.050, 245.0, 0.88)

func _queue_final_attack() -> void:
	# Final phase is an escalation of the already-established hard state, not the
	# first appearance of it. Speed jumps once at 48 seconds and stays fixed.
	var pattern: int = (gap_attack_index - 1) % 3

	if pattern == 0:
		var final_horizontal_side: int = 0 if gap_attack_index % 2 == 1 else 1
		var final_vertical_side: int = 2 if gap_attack_index % 2 == 1 else 3
		var final_horizontal_gap: float = _choose_gap_lane(0.26)
		var final_vertical_gap: float = rng.randf_range(0.16, 0.84)
		_queue_gap_wall(final_horizontal_side, final_horizontal_gap, 0.042, 260.0, 0.84)
		_queue_gap_wall(final_vertical_side, final_vertical_gap, 0.042, 260.0, 1.40)
	elif pattern == 1:
		# One fast single wall acts as a brief reset beat without reducing speed.
		var final_single_sides: Array[int] = [2, 1, 3, 0]
		var final_single_side: int = final_single_sides[(gap_attack_index - 1) % final_single_sides.size()]
		var final_single_gap: float = _choose_gap_lane(0.28)
		_queue_gap_wall(final_single_side, final_single_gap, 0.045, 260.0, 0.82)
	else:
		# Push both openings toward outer portions of the arena. The intersection
		# remains readable, but the required commitment is larger than a center gap.
		var tight_horizontal_side: int = 1 if gap_attack_index % 2 == 1 else 0
		var tight_vertical_side: int = 3 if gap_attack_index % 2 == 1 else 2
		var tight_horizontal_gap: float = _choose_edge_gap_lane()
		var tight_vertical_gap: float = _choose_edge_gap_lane()
		_queue_gap_wall(tight_horizontal_side, tight_horizontal_gap, 0.040, 260.0, 0.80)
		_queue_gap_wall(tight_vertical_side, tight_vertical_gap, 0.040, 260.0, 1.30)

func _choose_gap_lane(min_separation: float) -> float:
	var candidate: float = rng.randf_range(0.18, 0.82)
	if last_gap_lane < 0.0:
		last_gap_lane = candidate
		return candidate

	# Prefer a meaningfully different opening from the previous wall. A handful
	# of attempts prevents repetitive center camping without making it predictable.
	for _attempt in range(6):
		if absf(candidate - last_gap_lane) >= min_separation:
			break
		candidate = rng.randf_range(0.18, 0.82)

	last_gap_lane = candidate
	return candidate

func _choose_edge_gap_lane() -> float:
	if rng.randf() < 0.5:
		return rng.randf_range(0.14, 0.30)
	return rng.randf_range(0.70, 0.86)

func _queue_gap_wall(side: int, gap_lane: float, gap_half_width: float, speed: float, delay: float) -> void:
	var radius: float = 9.0
	var divisor: int = maxi(WALL_SLOT_COUNT - 1, 1)

	for index in range(WALL_SLOT_COUNT):
		var t: float = float(index) / float(divisor)
		var lane: float = lerpf(WALL_LANE_MIN, WALL_LANE_MAX, t)
		if absf(lane - gap_lane) <= gap_half_width:
			continue
		queue_projectile_warning(side, lane, speed, radius, delay)

func _get_spawn_interval(current_phase: int) -> float:
	match current_phase:
		1:
			return rng.randf_range(3.80, 4.10)
		2:
			return rng.randf_range(3.40, 3.70)
		3:
			return rng.randf_range(3.05, 3.30)
		4:
			return rng.randf_range(2.75, 3.00)
		_:
			return rng.randf_range(2.55, 2.80)

func _graze_enabled_for_phase(current_phase: int) -> bool:
	return current_phase > 0

func _get_intro_title() -> String:
	return "THE GAP"

func _get_intro_subtitle() -> String:
	return "LEVEL 4 — COMMITMENT"

func _get_intro_body() -> String:
	return "Projectile walls now cover almost the entire arena.\n\nEvery wall has one safe opening.\nFind it early and commit to the move.\nSurvive for 60 seconds.\n\nCLICK TO BEGIN"

func _get_pause_subtitle() -> String:
	return "LEVEL 4 — THE GAP"

func _get_countdown_tutorial_text() -> String:
	return "GET READY\nLook for the missing section in the wall."

func _get_countdown_subtitle() -> String:
	return "THE GAP"

func _get_death_title() -> String:
	return "RUN ENDED"

func _get_death_subtitle() -> String:
	return "LEVEL 4 — NO OPENING"

func _get_death_body(reason: String, run_time: float, final_score: int, best_score: int) -> String:
	return "%s\n\nTIME   %s / 1:00\nSCORE  %s\nBEST   %s\n\nCLICK OR PRESS R TO RETRY" % [reason.to_upper(), _format_time(run_time), _format_score(final_score), _format_score(best_score)]

func _get_win_title() -> String:
	return "LEVEL COMPLETE"

func _get_win_subtitle() -> String:
	return "THE GAP CLEARED"

func _get_win_tutorial_text() -> String:
	return "LEVEL COMPLETE\nTHE GAP CLEARED"

func _get_win_body(final_score: int, best_score: int) -> String:
	return "60 SECONDS SURVIVED\n\nCOMPLETION BONUS   +4,000\nFINAL SCORE        %s\nBEST SCORE         %s\n\nSafe-space reading and committed movement learned.\n\n%s" % [_format_score(final_score), _format_score(best_score), _get_win_action_text()]
