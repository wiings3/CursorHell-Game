extends "res://scripts/levels/standard_dodge_level.gd"
class_name CursorHellBoss01

const ROUND_TIME := 60.0
const COMPLETION_BONUS := 5000.0
const WALL_SLOT_COUNT := 19
const WALL_LANE_MIN := 0.06
const WALL_LANE_MAX := 0.94

var boss_attack_index := 0
var boss_phase := -1
var last_gap_lane := -1.0

func _reset_round(start_now: bool) -> void:
	boss_attack_index = 0
	boss_phase = -1
	last_gap_lane = -1.0
	super._reset_round(start_now)

func _get_level_number() -> int:
	return 5

func _get_round_time() -> float:
	return ROUND_TIME

func _get_completion_bonus() -> float:
	return COMPLETION_BONUS

func _get_phase() -> int:
	if elapsed < 5.0:
		return 0
	if elapsed < 15.0:
		return 1
	if elapsed < 27.0:
		return 2
	if elapsed < 39.0:
		return 3
	if elapsed < 52.0:
		return 4
	return 5

func _update_level_tutorial() -> void:
	match _get_phase():
		0:
			tutorial_label.text = "BOSS I // SYNTHESIS\nNothing new. Everything matters."
		1:
			tutorial_label.text = "READ BOTH SIDES\nSingles and crossfire share the arena now."
		2:
			tutorial_label.text = "READ THE ORDER\nSweeps arrive while paired pressure is already forming."
		3:
			tutorial_label.text = "FIND THE GAP\nThe opening solves the wall, not the next attack."
		4:
			tutorial_label.text = "SYNTHESIS\nRead lane, timing, direction and opening together."
		_:
			tutorial_label.text = "FINAL EXAM\nNo new rules. Prove you learned the old ones."

func _schedule_level_projectile(current_phase: int) -> void:
	if current_phase != boss_phase:
		boss_phase = current_phase
		boss_attack_index = 0
		last_gap_lane = -1.0
	boss_attack_index += 1

	match current_phase:
		1:
			_queue_opening_exam()
		2:
			_queue_sweep_exam()
		3:
			_queue_gap_exam()
		4:
			_queue_synthesis_exam(false)
		_:
			_queue_synthesis_exam(true)

func _queue_opening_exam() -> void:
	# First Contact + Crossfire. A familiar opposing pair establishes the main
	# read, then one ordinary single arrives on a different beat so the player
	# cannot treat the pair as the entire attack.
	var horizontal := boss_attack_index % 2 == 1
	_queue_crossfire_pair(horizontal, 180.0, 200.0, 0.90, 0.18, 0.28, 0.20)

	var single_side := rng.randi_range(0, 3)
	var single_lane := rng.randf_range(0.14, 0.86)
	queue_projectile_warning(single_side, single_lane, rng.randf_range(190.0, 210.0), 7.5, 1.42)

func _queue_sweep_exam() -> void:
	# Sweep direction is the primary problem. Crossfire appears after the sweep has
	# declared its direction, leaving time to understand both reads instead of
	# flashing every warning on the same frame.
	var sweep_sides: Array[int] = [0, 2, 1, 3]
	var sweep_side := sweep_sides[(boss_attack_index - 1) % sweep_sides.size()]
	var ascending := boss_attack_index % 2 == 1
	_queue_sweep(sweep_side, ascending, 7, 210.0, 0.76, 0.145, 0.10, 0.90)

	var horizontal_crossfire := sweep_side == 2 or sweep_side == 3
	_queue_crossfire_pair(horizontal_crossfire, 195.0, 215.0, 1.52, 0.18, 0.28, 0.22)

func _queue_gap_exam() -> void:
	# The wall is still solved exactly like THE GAP. Pressure from another axis is
	# deliberately delayed so the player can commit to the opening before the next
	# familiar read asks them to move again.
	var wall_sides: Array[int] = [0, 2, 1, 3]
	var wall_side := wall_sides[(boss_attack_index - 1) % wall_sides.size()]
	var gap := _choose_gap_lane(0.22)
	_queue_gap_wall(wall_side, gap, 0.075, 230.0, 0.78)

	var perpendicular_horizontal := wall_side == 2 or wall_side == 3
	if boss_attack_index % 2 == 1:
		_queue_crossfire_pair(perpendicular_horizontal, 205.0, 225.0, 1.58, 0.20, 0.30, 0.18)
	else:
		var sweep_side := 2 if wall_side == 0 or wall_side == 1 else 0
		if rng.randf() < 0.5:
			sweep_side += 1
		_queue_sweep(sweep_side, boss_attack_index % 4 == 0, 6, 215.0, 1.48, 0.14, 0.13, 0.87)

func _queue_synthesis_exam(finale: bool) -> void:
	var pattern := (boss_attack_index - 1) % 4
	var wall_speed := 250.0 if finale else 238.0
	var sweep_speed := 235.0 if finale else 220.0
	var pair_min := 220.0 if finale else 205.0
	var pair_max := 240.0 if finale else 225.0
	var wall_delay := 0.66 if finale else 0.76
	var follow_delay := 1.28 if finale else 1.46

	if pattern == 0:
		# Gap wall -> perpendicular crossfire.
		var side_a := 0 if boss_attack_index % 2 == 1 else 1
		var gap_width_a := 0.070 if finale else 0.078
		_queue_gap_wall(side_a, _choose_gap_lane(0.24), gap_width_a, wall_speed, wall_delay)
		_queue_crossfire_pair(false, pair_min, pair_max, follow_delay, 0.18, 0.28, 0.16)
	elif pattern == 1:
		# Sweep -> opposite-axis pair -> ordinary single late in the sequence.
		var side_b := 2 if boss_attack_index % 2 == 0 else 3
		var sweep_count := 8 if finale else 7
		var sweep_step := 0.125 if finale else 0.14
		_queue_sweep(side_b, boss_attack_index % 2 == 0, sweep_count, sweep_speed, wall_delay, sweep_step, 0.09, 0.91)
		_queue_crossfire_pair(true, pair_min, pair_max, follow_delay + 0.08, 0.18, 0.27, 0.16)
		queue_projectile_warning(rng.randi_range(0, 3), rng.randf_range(0.14, 0.86), pair_max, 7.5, follow_delay + 0.58)
	elif pattern == 2:
		# A vertical wall and horizontal sweep cross at different times. Both have
		# generous openings/read time; difficulty comes from planning two moves.
		var side_c := 2 if boss_attack_index % 2 == 1 else 3
		var gap_width_c := 0.070 if finale else 0.078
		_queue_gap_wall(side_c, _choose_gap_lane(0.24), gap_width_c, wall_speed, wall_delay)
		var sweep_side := 0 if boss_attack_index % 2 == 1 else 1
		_queue_sweep(sweep_side, boss_attack_index % 2 == 1, 7, sweep_speed, follow_delay, 0.13, 0.11, 0.89)
	else:
		# Crossfire starts the attack, then a wall forces a committed relocation.
		_queue_crossfire_pair(boss_attack_index % 2 == 0, pair_min, pair_max, wall_delay, 0.17, 0.27, 0.14)
		var side_d := rng.randi_range(0, 3)
		var gap_width_d := 0.072 if finale else 0.080
		_queue_gap_wall(side_d, _choose_gap_lane(0.25), gap_width_d, wall_speed, follow_delay)

func _queue_crossfire_pair(horizontal: bool, speed_min: float, speed_max: float, delay: float, gap_min: float, gap_max: float, stagger: float = 0.0) -> void:
	var center := rng.randf_range(0.32, 0.68)
	var gap := rng.randf_range(gap_min, gap_max)
	var lane_a := clampf(center - gap * 0.5, 0.12, 0.88)
	var lane_b := clampf(center + gap * 0.5, 0.12, 0.88)
	if rng.randf() < 0.5:
		var lane_swap := lane_a
		lane_a = lane_b
		lane_b = lane_swap

	var speed := rng.randf_range(speed_min, speed_max)
	var delay_a := delay
	var delay_b := delay + stagger
	if stagger > 0.0 and rng.randf() < 0.5:
		var delay_swap := delay_a
		delay_a = delay_b
		delay_b = delay_swap

	if horizontal:
		queue_projectile_warning(0, lane_a, speed, 7.0, delay_a)
		queue_projectile_warning(1, lane_b, speed, 7.0, delay_b)
	else:
		queue_projectile_warning(2, lane_a, speed, 7.0, delay_a)
		queue_projectile_warning(3, lane_b, speed, 7.0, delay_b)

func _queue_sweep(side: int, ascending: bool, count: int, speed: float, base_delay: float, step_delay: float, lane_min: float, lane_max: float) -> void:
	var divisor := maxi(count - 1, 1)
	for index in range(count):
		var t := float(index) / float(divisor)
		if not ascending:
			t = 1.0 - t
		var lane := lerpf(lane_min, lane_max, t)
		var delay := base_delay + float(index) * step_delay
		_queue_sweep_warning(side, lane, speed, 7.0, delay, index == 0)

func _queue_sweep_warning(side: int, lane: float, speed: float, radius: float, delay: float, is_first: bool) -> void:
	queue_projectile_warning(side, lane, speed, radius, delay)
	var warning_index := warnings.size() - 1
	if warning_index < 0:
		return
	var warning: Dictionary = warnings[warning_index]
	warning["sweep_visual"] = true
	warning["sweep_start"] = is_first
	warning["sweep_focus_time"] = 0.55
	warning["sweep_focus_width"] = 0.18

func _queue_gap_wall(side: int, gap_lane: float, gap_half_width: float, speed: float, delay: float) -> void:
	var divisor := maxi(WALL_SLOT_COUNT - 1, 1)
	for index in range(WALL_SLOT_COUNT):
		var lane := lerpf(WALL_LANE_MIN, WALL_LANE_MAX, float(index) / float(divisor))
		if absf(lane - gap_lane) <= gap_half_width:
			continue
		queue_projectile_warning(side, lane, speed, 9.0, delay)

func _choose_gap_lane(min_separation: float) -> float:
	var candidate := rng.randf_range(0.18, 0.82)
	if last_gap_lane < 0.0:
		last_gap_lane = candidate
		return candidate
	for _attempt in range(6):
		if absf(candidate - last_gap_lane) >= min_separation:
			break
		candidate = rng.randf_range(0.18, 0.82)
	last_gap_lane = candidate
	return candidate

func _get_spawn_interval(current_phase: int) -> float:
	match current_phase:
		1:
			return rng.randf_range(2.55, 2.80)
		2:
			return rng.randf_range(2.65, 2.90)
		3:
			return rng.randf_range(2.70, 2.95)
		4:
			return rng.randf_range(2.45, 2.70)
		_:
			return rng.randf_range(2.20, 2.40)

func _graze_enabled_for_phase(current_phase: int) -> bool:
	return current_phase > 0

func _get_intro_title() -> String:
	return "SYNTHESIS"

func _get_intro_subtitle() -> String:
	return "LEVEL 5 — BOSS I"

func _get_intro_body() -> String:
	return "Four lessons. One test.\n\nFIRST CONTACT. CROSSFIRE. THE SWEEP. THE GAP.\nNothing here is new, but nothing arrives alone anymore.\nRead the whole arena and survive for 60 seconds.\n\nCLICK TO BEGIN"

func _get_pause_subtitle() -> String:
	return "LEVEL 5 — BOSS I"

func _get_countdown_tutorial_text() -> String:
	return "BOSS I\nYou already know every rule."

func _get_countdown_subtitle() -> String:
	return "SYNTHESIS"

func _get_death_title() -> String:
	return "BOSS FAILED"

func _get_death_subtitle() -> String:
	return "LEVEL 5 — SYNTHESIS"

func _get_death_body(reason: String, run_time: float, final_score: int, best_score: int) -> String:
	return "%s\n\nTIME   %s / 1:00\nSCORE  %s\nBEST   %s\n\nCLICK OR PRESS R TO RETRY" % [reason.to_upper(), _format_time(run_time), _format_score(final_score), _format_score(best_score)]

func _get_win_title() -> String:
	return "BOSS CLEARED"

func _get_win_subtitle() -> String:
	return "SYNTHESIS COMPLETE"

func _get_win_tutorial_text() -> String:
	return "BOSS I CLEARED\nSYNTHESIS COMPLETE"

func _get_win_body(final_score: int, best_score: int) -> String:
	return "60 SECONDS SURVIVED\n\nBOSS BONUS         +5,000\nFINAL SCORE        %s\nBEST SCORE         %s\n\nThe first four survival tests mastered together.\n\n%s" % [_format_score(final_score), _format_score(best_score), _get_win_action_text()]
