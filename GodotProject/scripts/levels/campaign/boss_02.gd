extends "res://scripts/levels/level_08.gd"
class_name CursorHellBoss02

const BOSS_ROUND_TIME := 60.0
const BOSS_COMPLETION_BONUS := 8000.0
const STANDARD_FAST_RADIUS := 7.0

# Boss II was landing a little too far above the intended difficulty curve.
# These shared tuning multipliers pull the whole fight back by roughly 15% in
# feel without changing its patterns or removing any of the four tested systems.
const BOSS_PROJECTILE_SPEED_SCALE := 0.92
const BOSS_WARNING_TIME_SCALE := 1.06
const BOSS_SPAWN_INTERVAL_SCALE := 1.08
const BOSS_PYLON_RADIUS_SCALE := 0.94
const BOSS_PYLON_ACTIVE_SCALE := 0.94
const BOSS_PYLON_TRAVEL_SCALE := 1.06
const BOSS_PYLON_ARM_SCALE := 1.08

var boss_attack_index := 0
var boss_phase := -1
var last_flood_side := -1

func _reset_round(start_now: bool) -> void:
	boss_attack_index = 0
	boss_phase = -1
	last_flood_side = -1
	super._reset_round(start_now)

func _get_level_number() -> int:
	return 10

func _get_round_time() -> float:
	return BOSS_ROUND_TIME

func _get_completion_bonus() -> float:
	return BOSS_COMPLETION_BONUS

func _get_phase() -> int:
	if elapsed < 5.0:
		return 0
	if elapsed < 16.0:
		return 1
	if elapsed < 28.0:
		return 2
	if elapsed < 40.0:
		return 3
	if elapsed < 52.0:
		return 4
	return 5

func _update_level_tutorial() -> void:
	match _get_phase():
		0:
			tutorial_label.text = "BOSS II // CONVERGENCE\nFour systems. One arena."
		1:
			tutorial_label.text = "TIMING + MEMORY\nThe pulse returns. Do not trust the space it just cleared."
		2:
			tutorial_label.text = "PERSISTENCE + TIMING\nOld danger stays while the next beat arrives."
		3:
			tutorial_label.text = "TERRITORY + MEMORY\nDead zones shrink the arena while echoes attack the exits."
		4:
			tutorial_label.text = "CONVERGENCE\nRead the floor, the beat, the echo and the route together."
		_:
			tutorial_label.text = "FINAL EXAM\nEverything overlaps. Keep an exit before you need it."

func _schedule_level_projectile(current_phase: int) -> void:
	if current_phase != boss_phase:
		boss_phase = current_phase
		boss_attack_index = 0
	boss_attack_index += 1

	match current_phase:
		1:
			_queue_temporal_combo()
		2:
			_queue_flood_pulse_combo()
		3:
			_queue_territory_memory_combo()
		4:
			_queue_convergence_combo(false)
		_:
			_queue_convergence_combo(true)

func _queue_temporal_combo() -> void:
	# THE PULSE + AFTERSHOCK. The first synchronized volley establishes the beat;
	# the second volley repeats or shifts that solution before the player can reset.
	var horizontal := boss_attack_index % 2 == 1
	var offset := 0.035 if boss_attack_index % 4 < 2 else -0.035
	_queue_axis_pulse(horizontal, 6, 270.0, 0.82, offset)

	if boss_attack_index % 3 == 0:
		_queue_axis_pulse(not horizontal, 5, 278.0, 1.28, -offset)
	else:
		_queue_axis_pulse(horizontal, 6, 278.0, 1.32, -offset)

func _queue_flood_pulse_combo() -> void:
	# THE FLOOD + THE PULSE. Slow blockers build temporary terrain while the beat
	# forces movement through it. Every second attack adds a shifted follow-up beat.
	var blocker_count := 3 if boss_attack_index % 3 == 0 else 2
	_queue_flood_blockers(blocker_count, 114.0, 19.0, 0.78)

	var horizontal := boss_attack_index % 2 == 0
	var offset := 0.030 if boss_attack_index % 4 < 2 else -0.030
	_queue_axis_pulse(horizontal, 6, 282.0, 0.58, offset)

	var fast_side := _perpendicular_side_for_axis(horizontal)
	_queue_targeted_standard_burst(fast_side, 5, 330.0, 1.02, 0.050)

	if boss_attack_index % 2 == 0:
		_queue_axis_pulse(horizontal, 6, 286.0, 1.28, -offset)

func _queue_territory_memory_combo() -> void:
	# DEAD ZONES + AFTERSHOCK. Pylons reduce the number of usable pockets, then a
	# primary/echo pair attacks the route the player actually chose. Needles keep
	# the remaining open space from becoming passive.
	if _live_pylon_count() < 2 and boss_attack_index % 2 == 1:
		_spawn_pylon(2, 150.0, 5.3, 1.00, 0.95)

	var side := rng.randi_range(0, 3)
	var center := _target_lane_for_side(side, 0.055)
	var shift := 0.050 if boss_attack_index % 2 == 0 else -0.050
	_queue_echo_band(side, center, 5, 0.050, 335.0, 0.60)
	_queue_echo_band(side, clampf(center + shift, 0.14, 0.86), 5, 0.050, 342.0, 1.04)

	var forced_axis := 1 if side == 0 or side == 1 else 0
	var needle_count := 5 if boss_attack_index % 3 == 0 else 4
	_queue_targeted_needles(needle_count, 700.0, 0.48, 0.034, forced_axis)

func _queue_convergence_combo(finale: bool) -> void:
	var pattern := (boss_attack_index - 1) % 4
	var pylon_limit := 3 if finale else 2
	var pylon_radius := 158.0 if finale else 153.0
	var pylon_active := 5.0 if finale else 5.3
	var pylon_travel := 0.86 if finale else 0.96
	var pylon_arm := 0.78 if finale else 0.88
	var needle_speed := 810.0 if finale else 740.0
	var standard_speed := 360.0 if finale else 340.0
	var pulse_speed := 300.0 if finale else 288.0

	if _live_pylon_count() < pylon_limit and (finale or boss_attack_index % 2 == 1):
		_spawn_pylon(pylon_limit, pylon_radius, pylon_active, pylon_travel, pylon_arm)

	if pattern == 0:
		# Pulse corridors are immediately tested by fast needles from the other axis.
		var horizontal := boss_attack_index % 2 == 1
		_queue_axis_pulse(horizontal, 7 if finale else 6, pulse_speed, 0.50, -0.035)
		_queue_axis_pulse(horizontal, 7 if finale else 6, pulse_speed + 6.0, 0.96, 0.035)
		_queue_targeted_needles(6 if finale else 5, needle_speed, 0.70, 0.032, 1 if horizontal else 0)
	elif pattern == 1:
		# Flood geography plus an echo sequence. The needle burst attacks the route
		# between them rather than simply adding more large standard projectiles.
		_queue_flood_blockers(3, 124.0 if finale else 120.0, 20.0, 0.62)
		var side := rng.randi_range(0, 3)
		var center := _target_lane_for_side(side, 0.050)
		_queue_echo_band(side, center, 7 if finale else 5, 0.044, standard_speed, 0.48)
		_queue_echo_band((side + 2) % 4, clampf(center + 0.050, 0.14, 0.86), 5, 0.048, standard_speed + 8.0, 0.90)
		_queue_targeted_needles(5, needle_speed + 20.0, 1.08, 0.034)
	elif pattern == 2:
		# A simultaneous pulse makes the player commit while persistent blockers and
		# the pylon field make returning to the old solution unreliable.
		_queue_flood_blockers(2, 122.0 if finale else 118.0, 19.0, 0.76)
		_queue_axis_pulse(true, 6, pulse_speed, 0.52, -0.030)
		_queue_axis_pulse(false, 6, pulse_speed, 0.52, 0.030)
		var echo_side := rng.randi_range(0, 3)
		_queue_echo_band(echo_side, _target_lane_for_side(echo_side, 0.045), 5, 0.048, standard_speed, 1.02)
	else:
		# Needles force the first relocation, then a pulse/echo pair closes the easy
		# retreat. This is the most movement-heavy pattern but still uses known rules.
		var primary_axis := 0 if final_axis_horizontal else 1
		final_axis_horizontal = not final_axis_horizontal
		_queue_targeted_needles(7 if finale else 6, needle_speed + 20.0, 0.44, 0.031, primary_axis)
		_queue_axis_pulse(primary_axis == 1, 6, pulse_speed, 0.76, 0.0)
		var echo_side := 2 if primary_axis == 0 else 0
		if rng.randf() < 0.5:
			echo_side += 1
		var echo_center := _target_lane_for_side(echo_side, 0.040)
		_queue_echo_band(echo_side, echo_center, 5, 0.047, standard_speed + 6.0, 1.08)
		_queue_echo_band(echo_side, clampf(echo_center - 0.055, 0.14, 0.86), 5, 0.047, standard_speed + 12.0, 1.38)

func _queue_axis_pulse(horizontal: bool, lane_count: int, speed: float, delay: float, lane_offset: float) -> void:
	var tuned_speed := speed * BOSS_PROJECTILE_SPEED_SCALE
	var tuned_delay := delay * BOSS_WARNING_TIME_SCALE
	var divisor := maxi(lane_count - 1, 1)
	for index in range(lane_count):
		var lane := lerpf(0.12, 0.88, float(index) / float(divisor)) + lane_offset
		lane = clampf(lane, 0.07, 0.93)
		if horizontal:
			queue_projectile_warning(0, lane, tuned_speed, 8.0, tuned_delay)
			queue_projectile_warning(1, lane, tuned_speed, 8.0, tuned_delay)
		else:
			queue_projectile_warning(2, lane, tuned_speed, 8.0, tuned_delay)
			queue_projectile_warning(3, lane, tuned_speed, 8.0, tuned_delay)

func _queue_echo_band(side: int, center_lane: float, count: int, spacing: float, speed: float, delay: float) -> void:
	var tuned_speed := speed * BOSS_PROJECTILE_SPEED_SCALE
	var tuned_delay := delay * BOSS_WARNING_TIME_SCALE
	var half := int(count / 2)
	for index in range(count):
		var lane := clampf(center_lane + float(index - half) * spacing, 0.06, 0.94)
		queue_projectile_warning(side, lane, tuned_speed, STANDARD_FAST_RADIUS, tuned_delay)

func _queue_flood_blockers(count: int, speed: float, radius: float, base_delay: float) -> void:
	var tuned_speed := speed * BOSS_PROJECTILE_SPEED_SCALE
	var tuned_delay := base_delay * BOSS_WARNING_TIME_SCALE
	for index in range(count):
		var side := _next_flood_side()
		var lane := rng.randf_range(0.16, 0.84)
		queue_projectile_warning(side, lane, tuned_speed, radius, tuned_delay + float(index) * 0.19)

func _queue_targeted_standard_burst(side: int, count: int, speed: float, delay: float, spacing: float) -> void:
	var tuned_speed := speed * BOSS_PROJECTILE_SPEED_SCALE
	var tuned_delay := delay * BOSS_WARNING_TIME_SCALE
	var center := _target_lane_for_side(side, 0.025)
	var half := int(count / 2)
	for index in range(count):
		var lane := clampf(center + float(index - half) * spacing, 0.05, 0.95)
		queue_projectile_warning(side, lane, tuned_speed, STANDARD_FAST_RADIUS, tuned_delay)

func _queue_targeted_needles(count: int, speed: float, delay: float, spread: float, forced_axis: int = -1) -> void:
	# Preserve the approved needle group sizes and identity, but give the player a
	# little more reaction time and slightly reduce their travel speed in Boss II.
	super._queue_targeted_needles(
		count,
		speed * BOSS_PROJECTILE_SPEED_SCALE,
		delay * BOSS_WARNING_TIME_SCALE,
		spread,
		forced_axis
	)

func _spawn_pylon(max_active: int, radius: float, active_duration: float, travel_duration: float, arm_duration: float) -> void:
	# The same pylon patterns remain, but each zone steals a little less space and
	# gives slightly more travel/arming time before becoming lethal.
	super._spawn_pylon(
		max_active,
		radius * BOSS_PYLON_RADIUS_SCALE,
		active_duration * BOSS_PYLON_ACTIVE_SCALE,
		travel_duration * BOSS_PYLON_TRAVEL_SCALE,
		arm_duration * BOSS_PYLON_ARM_SCALE
	)

func _next_flood_side() -> int:
	var side := rng.randi_range(0, 3)
	if side == last_flood_side:
		side = (side + rng.randi_range(1, 3)) % 4
	last_flood_side = side
	return side

func _perpendicular_side_for_axis(horizontal: bool) -> int:
	if horizontal:
		return 2 if rng.randf() < 0.5 else 3
	return 0 if rng.randf() < 0.5 else 1

func _get_spawn_interval(current_phase: int) -> float:
	match current_phase:
		1:
			return rng.randf_range(2.55, 2.80) * BOSS_SPAWN_INTERVAL_SCALE
		2:
			return rng.randf_range(2.25, 2.50) * BOSS_SPAWN_INTERVAL_SCALE
		3:
			return rng.randf_range(2.00, 2.22) * BOSS_SPAWN_INTERVAL_SCALE
		4:
			return rng.randf_range(1.78, 2.00) * BOSS_SPAWN_INTERVAL_SCALE
		_:
			return rng.randf_range(1.55, 1.72) * BOSS_SPAWN_INTERVAL_SCALE

func _graze_enabled_for_phase(current_phase: int) -> bool:
	return current_phase > 0

func _get_intro_title() -> String:
	return "CONVERGENCE"

func _get_intro_subtitle() -> String:
	return "LEVEL 10 — BOSS II"

func _get_intro_body() -> String:
	return "Four more lessons. One arena.\n\nTHE PULSE. THE FLOOD. AFTERSHOCK. DEAD ZONES.\nTiming, persistence, memory and territory now overlap.\nNothing here is new. Survive the combination for 60 seconds.\n\nCLICK TO BEGIN"

func _get_pause_subtitle() -> String:
	return "LEVEL 10 — BOSS II"

func _get_countdown_tutorial_text() -> String:
	return "BOSS II\nKeep an exit before you need it."

func _get_countdown_subtitle() -> String:
	return "CONVERGENCE"

func _get_death_title() -> String:
	return "BOSS FAILED"

func _get_death_subtitle() -> String:
	return "LEVEL 10 — CONVERGENCE"

func _get_death_body(reason: String, run_time: float, final_score: int, best_score: int) -> String:
	return "%s\n\nTIME   %s / 1:00\nSCORE  %s\nBEST   %s\n\nCLICK OR PRESS R TO RETRY" % [reason.to_upper(), _format_time(run_time), _format_score(final_score), _format_score(best_score)]

func _get_win_title() -> String:
	return "BOSS CLEARED"

func _get_win_subtitle() -> String:
	return "CONVERGENCE BROKEN"

func _get_win_tutorial_text() -> String:
	return "BOSS CLEARED\nCONVERGENCE BROKEN"

func _get_win_body(final_score: int, best_score: int) -> String:
	return "60 SECONDS SURVIVED\n\nCOMPLETION BONUS   +8,000\nFINAL SCORE        %s\nBEST SCORE         %s\n\nTiming, persistence, memory and territory mastered together.\n\n%s" % [_format_score(final_score), _format_score(best_score), _get_win_action_text()]
