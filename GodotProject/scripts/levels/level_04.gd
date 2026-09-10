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
	if elapsed < 6.0:
		return 0
	if elapsed < 22.0:
		return 1
	if elapsed < 38.0:
		return 2
	if elapsed < 52.0:
		return 3
	return 4

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
		_:
			tutorial_label.text = "TWO WALLS\nRead both openings. Move toward their intersection."

func _schedule_level_projectile(current_phase: int) -> void:
	# Reset the local attack rhythm at each phase transition so every lesson begins
	# with a predictable side pattern instead of inheriting parity from the last one.
	if current_phase != gap_phase:
		gap_phase = current_phase
		gap_attack_index = 0
		last_gap_lane = -1.0
	gap_attack_index += 1

	match current_phase:
		1:
			# The first opening is still readable, but no longer wide enough to solve
			# the wall with a vague move toward the middle of the gap.
			var phase1_gap: float = _choose_gap_lane(0.18)
			_queue_gap_wall(0, phase1_gap, 0.075, 205.0, 1.20)
		2:
			# Alternate left and right with a tighter opening and faster travel time.
			var phase2_side: int = 0 if gap_attack_index % 2 == 1 else 1
			var phase2_gap: float = _choose_gap_lane(0.22)
			_queue_gap_wall(phase2_side, phase2_gap, 0.060, 220.0, 1.08)
		3:
			# Carry the same safe-gap read around all four edges. Outside the authored
			# opening, adjacent shots are too close for the player hitbox to thread.
			var phase3_sides: Array[int] = [0, 2, 1, 3]
			var phase3_side: int = phase3_sides[(gap_attack_index - 1) % phase3_sides.size()]
			var phase3_gap: float = _choose_gap_lane(0.22)
			_queue_gap_wall(phase3_side, phase3_gap, 0.050, 235.0, 0.96)
		_:
			# Finale: two fast perpendicular walls are telegraphed together. The gaps
			# are deliberately narrow, so reaching their intersection requires a real
			# commitment instead of simply drifting toward the general open area.
			var horizontal_side: int = 0 if gap_attack_index % 2 == 1 else 1
			var vertical_side: int = 2 if gap_attack_index % 2 == 1 else 3
			var horizontal_gap: float = _choose_gap_lane(0.24)
			var vertical_gap: float = rng.randf_range(0.18, 0.82)
			_queue_gap_wall(horizontal_side, horizontal_gap, 0.045, 250.0, 0.90)
			_queue_gap_wall(vertical_side, vertical_gap, 0.045, 245.0, 1.62)

func _choose_gap_lane(min_separation: float) -> float:
	var candidate: float = rng.randf_range(0.18, 0.82)
	if last_gap_lane < 0.0:
		last_gap_lane = candidate
		return candidate

	# Prefer a meaningfully different opening from the previous wall. A handful
	# of attempts is enough to prevent repetitive center camping without making
	# the gap location deterministic.
	for _attempt in range(6):
		if absf(candidate - last_gap_lane) >= min_separation:
			break
		candidate = rng.randf_range(0.18, 0.82)

	last_gap_lane = candidate
	return candidate

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
			return rng.randf_range(4.25, 4.55)
		2:
			return rng.randf_range(3.85, 4.10)
		3:
			return rng.randf_range(3.45, 3.70)
		_:
			return rng.randf_range(3.90, 4.15)

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
