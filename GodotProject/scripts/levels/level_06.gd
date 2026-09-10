extends "res://scripts/levels/standard_dodge_level.gd"
class_name CursorHellLevel06

const ROUND_TIME := 60.0
const COMPLETION_BONUS := 5000.0
const FAST_PROJECTILE_RADIUS := 7.0

var flood_attack_index := 0
var flood_phase := -1
var last_slow_side := -1

func _reset_round(start_now: bool) -> void:
	flood_attack_index = 0
	flood_phase = -1
	last_slow_side = -1
	super._reset_round(start_now)

func _get_level_number() -> int:
	return 6

func _get_round_time() -> float:
	return ROUND_TIME

func _get_completion_bonus() -> float:
	return COMPLETION_BONUS

func _get_phase() -> int:
	if elapsed < 5.0:
		return 0
	if elapsed < 12.0:
		return 1
	if elapsed < 22.0:
		return 2
	if elapsed < 34.0:
		return 3
	if elapsed < 48.0:
		return 4
	return 5

func _update_level_tutorial() -> void:
	match _get_phase():
		0:
			tutorial_label.text = "THE FLOOD\nSome threats do not leave quickly."
		1:
			tutorial_label.text = "LINGERING DANGER\nLarge slow projectiles stay in the arena. Route around them."
		2:
			tutorial_label.text = "SPACE DISAPPEARS\nFast fire now attacks the space you are using."
		3:
			tutorial_label.text = "MOVE OR DROWN\nBlockers stay. Fast volleys force you out."
		4:
			tutorial_label.text = "THE FLOOD\nEvery safe pocket is temporary."
		_:
			tutorial_label.text = "NO ROOM\nRead the opening and commit immediately."

func _schedule_level_projectile(current_phase: int) -> void:
	if current_phase != flood_phase:
		flood_phase = current_phase
		flood_attack_index = 0
		last_slow_side = -1
	flood_attack_index += 1

	match current_phase:
		1:
			_queue_intro_blockers()
		2:
			_queue_lingering_pressure()
		3:
			_queue_mixed_attack()
		4:
			_queue_pressure_attack()
		_:
			_queue_final_attack()

func _queue_intro_blockers() -> void:
	# The opener still teaches the level identity cleanly before the fast layer arrives.
	var side: int = 0 if flood_attack_index % 2 == 1 else 1
	var lane_a: float = rng.randf_range(0.18, 0.40)
	var lane_b: float = rng.randf_range(0.60, 0.82)
	_queue_slow_projectile(side, lane_a, 108.0, 17.0, 1.02)
	_queue_slow_projectile(side, lane_b, 108.0, 17.0, 1.18)

func _queue_lingering_pressure() -> void:
	# From 12 seconds onward the fast layer is no longer random decoration. It is
	# aimed through the player's current lane, forcing them to abandon whatever
	# pocket the persistent blockers have allowed them to settle into.
	var primary_side: int = _next_slow_side()
	var secondary_side: int = (primary_side + 1 + (flood_attack_index % 2)) % 4
	var lane_a: float = rng.randf_range(0.16, 0.84)
	var lane_b: float = _separated_lane(lane_a, 0.24)
	var lane_c: float = _separated_lane(lane_b, 0.22)

	_queue_slow_projectile(primary_side, lane_a, 110.0, 18.0, 0.96)
	_queue_slow_projectile(secondary_side, lane_b, 112.0, 18.0, 1.14)
	_queue_slow_projectile((primary_side + 2) % 4, lane_c, 112.0, 17.0, 1.34)

	var fast_side: int = (secondary_side + 2) % 4
	_queue_targeted_fast_burst(fast_side, 5, 275.0, 0.70, 0.050)

	if flood_attack_index % 2 == 0:
		_queue_targeted_fast_burst((fast_side + 1) % 4, 5, 275.0, 1.02, 0.048)

func _queue_mixed_attack() -> void:
	# Persistent terrain plus two player-denial bursts. The first forces movement;
	# the second arrives from a perpendicular direction while the player is moving.
	var blocker_side: int = _next_slow_side()
	var blocker_lane_a: float = rng.randf_range(0.16, 0.44)
	var blocker_lane_b: float = rng.randf_range(0.56, 0.84)
	_queue_slow_projectile(blocker_side, blocker_lane_a, 114.0, 19.0, 0.88)
	_queue_slow_projectile((blocker_side + 1) % 4, blocker_lane_b, 116.0, 18.0, 1.06)

	var fast_side: int = (blocker_side + 2) % 4
	_queue_targeted_fast_burst(fast_side, 7, 295.0, 0.62, 0.043)
	_queue_targeted_fast_burst((fast_side + 1) % 4, 5, 295.0, 0.96, 0.048)

	if flood_attack_index % 2 == 0:
		_queue_fast_curtain((fast_side + 2) % 4, 295.0, 1.24, 11, 0.14)

func _queue_pressure_attack() -> void:
	# Hard state: every attack deliberately closes the player's current pocket.
	# Slow blockers create the geography; targeted bursts and partial curtains make
	# escaping through that geography the actual challenge.
	var pattern: int = (flood_attack_index - 1) % 4

	if pattern == 0:
		_queue_cross_blockers(118.0, 20.0, 0.78)
		_queue_slow_projectile(_next_slow_side(), rng.randf_range(0.20, 0.80), 118.0, 19.0, 1.00)
		var side_a: int = rng.randi_range(0, 3)
		_queue_targeted_fast_burst(side_a, 7, 315.0, 0.54, 0.042)
		_queue_targeted_fast_burst((side_a + 1) % 4, 7, 315.0, 0.84, 0.042)
	elif pattern == 1:
		var side_b: int = _next_slow_side()
		_queue_slow_projectile(side_b, rng.randf_range(0.14, 0.36), 120.0, 20.0, 0.76)
		_queue_slow_projectile(side_b, rng.randf_range(0.42, 0.62), 120.0, 18.0, 0.94)
		_queue_slow_projectile(side_b, rng.randf_range(0.66, 0.86), 120.0, 20.0, 1.12)
		_queue_fast_curtain((side_b + 2) % 4, 315.0, 0.52, 13, 0.12)
		_queue_targeted_fast_burst((side_b + 1) % 4, 7, 315.0, 0.88, 0.040)
	elif pattern == 2:
		_queue_cross_blockers(120.0, 20.0, 0.74)
		_queue_cross_blockers(122.0, 18.0, 1.08)
		var side_c: int = rng.randi_range(0, 3)
		_queue_targeted_fast_burst(side_c, 9, 315.0, 0.50, 0.036)
		_queue_targeted_fast_burst((side_c + 1) % 4, 7, 315.0, 0.80, 0.040)
	else:
		var side_d: int = _next_slow_side()
		_queue_slow_projectile(side_d, rng.randf_range(0.18, 0.82), 120.0, 21.0, 0.74)
		_queue_slow_projectile((side_d + 1) % 4, rng.randf_range(0.18, 0.82), 120.0, 19.0, 0.96)
		_queue_fast_crossfire(315.0, 0.50, 0.18)
		_queue_fast_curtain((side_d + 2) % 4, 315.0, 0.90, 11, 0.13)

func _queue_final_attack() -> void:
	# Final phase keeps the Flood rules but removes most breathing room. The fast
	# layer jumps once more and repeatedly attacks the player's occupied lanes while
	# dense curtains leave only a narrow route through the lingering blockers.
	var pattern: int = (flood_attack_index - 1) % 3

	if pattern == 0:
		_queue_cross_blockers(124.0, 22.0, 0.70)
		_queue_slow_projectile(_next_slow_side(), rng.randf_range(0.18, 0.82), 124.0, 20.0, 0.92)
		var side_a: int = rng.randi_range(0, 3)
		_queue_targeted_fast_burst(side_a, 9, 335.0, 0.44, 0.036)
		_queue_targeted_fast_burst((side_a + 1) % 4, 9, 335.0, 0.72, 0.036)
		_queue_fast_curtain((side_a + 2) % 4, 335.0, 1.02, 13, 0.11)
	elif pattern == 1:
		var side_b: int = _next_slow_side()
		_queue_slow_projectile(side_b, rng.randf_range(0.16, 0.38), 125.0, 22.0, 0.68)
		_queue_slow_projectile(side_b, rng.randf_range(0.62, 0.84), 125.0, 22.0, 0.88)
		_queue_slow_projectile((side_b + 1) % 4, rng.randf_range(0.24, 0.76), 125.0, 20.0, 1.06)
		_queue_fast_curtain((side_b + 2) % 4, 335.0, 0.42, 15, 0.10)
		_queue_targeted_fast_burst((side_b + 1) % 4, 9, 335.0, 0.78, 0.035)
	else:
		var start_side: int = _next_slow_side()
		for offset in range(4):
			var blocker_side: int = (start_side + offset) % 4
			var blocker_lane: float = rng.randf_range(0.16, 0.84)
			_queue_slow_projectile(blocker_side, blocker_lane, 125.0, 21.0, 0.66 + float(offset) * 0.16)
		_queue_fast_crossfire(335.0, 0.40, 0.15)
		_queue_targeted_fast_burst((start_side + 2) % 4, 9, 335.0, 0.76, 0.034)
		_queue_fast_curtain((start_side + 3) % 4, 335.0, 1.02, 13, 0.11)

func _queue_cross_blockers(speed: float, radius: float, delay: float) -> void:
	var horizontal_side: int = 0 if flood_attack_index % 2 == 1 else 1
	var vertical_side: int = 2 if flood_attack_index % 2 == 1 else 3
	var horizontal_lane: float = rng.randf_range(0.18, 0.82)
	var vertical_lane: float = _separated_lane(horizontal_lane, 0.22)
	_queue_slow_projectile(horizontal_side, horizontal_lane, speed, radius, delay)
	_queue_slow_projectile(vertical_side, vertical_lane, speed, radius, delay + 0.20)

func _queue_fast_crossfire(speed: float, delay: float, stagger: float) -> void:
	# Both axes target the player's current lanes. The second axis is staggered just
	# enough that the player can read it, but not enough to return to the old pocket.
	var horizontal_side: int = 0 if rng.randf() < 0.5 else 1
	var vertical_side: int = 2 if rng.randf() < 0.5 else 3
	_queue_targeted_fast_burst(horizontal_side, 7, speed, delay, 0.040)
	_queue_targeted_fast_burst(vertical_side, 7, speed, delay + stagger, 0.040)

func _queue_targeted_fast_burst(side: int, count: int, speed: float, delay: float, spacing: float) -> void:
	var center_lane: float = _player_lane_for_side(side)
	var half_count: int = count / 2
	for index in range(count):
		var offset: int = index - half_count
		var lane: float = clampf(center_lane + float(offset) * spacing, 0.05, 0.95)
		queue_projectile_warning(side, lane, speed, FAST_PROJECTILE_RADIUS, delay)

func _queue_fast_curtain(side: int, speed: float, delay: float, lane_count: int, gap_half_width: float) -> void:
	# A dense small-projectile curtain fills most of one edge, but always leaves a
	# deliberate opening. The gap is placed away from the player's current lane so
	# the curtain demands a real relocation instead of a tiny sidestep.
	var player_lane: float = _player_lane_for_side(side)
	var gap_lane: float = rng.randf_range(0.18, 0.36) if player_lane > 0.5 else rng.randf_range(0.64, 0.82)
	var divisor: int = maxi(lane_count - 1, 1)

	for index in range(lane_count):
		var lane: float = lerpf(0.06, 0.94, float(index) / float(divisor))
		if absf(lane - gap_lane) <= gap_half_width:
			continue
		queue_projectile_warning(side, lane, speed, FAST_PROJECTILE_RADIUS, delay)

func _player_lane_for_side(side: int) -> float:
	if side == 0 or side == 1:
		return clampf((player.position.y - ARENA.position.y) / ARENA.size.y, 0.05, 0.95)
	return clampf((player.position.x - ARENA.position.x) / ARENA.size.x, 0.05, 0.95)

func _queue_slow_projectile(side: int, lane: float, speed: float, radius: float, delay: float) -> void:
	queue_projectile_warning(side, lane, speed, radius, delay)

func _next_slow_side() -> int:
	var side: int = rng.randi_range(0, 3)
	if side == last_slow_side:
		side = (side + rng.randi_range(1, 3)) % 4
	last_slow_side = side
	return side

func _separated_lane(reference: float, minimum_distance: float) -> float:
	var candidate: float = rng.randf_range(0.16, 0.84)
	for _attempt in range(6):
		if absf(candidate - reference) >= minimum_distance:
			break
		candidate = rng.randf_range(0.16, 0.84)
	return candidate

func _get_spawn_interval(current_phase: int) -> float:
	match current_phase:
		1:
			return rng.randf_range(3.00, 3.20)
		2:
			return rng.randf_range(2.55, 2.80)
		3:
			return rng.randf_range(2.15, 2.40)
		4:
			return rng.randf_range(1.75, 2.00)
		_:
			return rng.randf_range(1.50, 1.75)

func _graze_enabled_for_phase(current_phase: int) -> bool:
	return current_phase > 0

func _get_intro_title() -> String:
	return "THE FLOOD"

func _get_intro_subtitle() -> String:
	return "LEVEL 6 — PERSISTENCE"

func _get_intro_body() -> String:
	return "Not every threat leaves quickly.\n\nLarge slow projectiles linger and steal space while faster attacks keep coming.\nDo not only read what is entering. Remember what is already inside.\nSurvive for 60 seconds.\n\nCLICK TO BEGIN"

func _get_pause_subtitle() -> String:
	return "LEVEL 6 — THE FLOOD"

func _get_countdown_tutorial_text() -> String:
	return "GET READY\nOld danger will still be there when the next attack arrives."

func _get_countdown_subtitle() -> String:
	return "THE FLOOD"

func _get_death_title() -> String:
	return "RUN ENDED"

func _get_death_subtitle() -> String:
	return "LEVEL 6 — SUBMERGED"

func _get_death_body(reason: String, run_time: float, final_score: int, best_score: int) -> String:
	return "%s\n\nTIME   %s / 1:00\nSCORE  %s\nBEST   %s\n\nCLICK OR PRESS R TO RETRY" % [reason.to_upper(), _format_time(run_time), _format_score(final_score), _format_score(best_score)]

func _get_win_title() -> String:
	return "LEVEL COMPLETE"

func _get_win_subtitle() -> String:
	return "THE FLOOD CLEARED"

func _get_win_tutorial_text() -> String:
	return "LEVEL COMPLETE\nTHE FLOOD CLEARED"

func _get_win_body(final_score: int, best_score: int) -> String:
	return "60 SECONDS SURVIVED\n\nCOMPLETION BONUS   +5,000\nFINAL SCORE        %s\nBEST SCORE         %s\n\nPersistent threats and shrinking safe space survived.\n\n%s" % [_format_score(final_score), _format_score(best_score), _get_win_action_text()]
