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
			tutorial_label.text = "SPACE DISAPPEARS\nMore blockers enter before the old ones are gone."
		3:
			tutorial_label.text = "TWO SPEEDS\nFast attacks now cut through the shrinking safe space."
		4:
			tutorial_label.text = "THE FLOOD\nOld danger stays. New danger keeps coming."
		_:
			tutorial_label.text = "NO ROOM\nFind the pocket, then be ready to abandon it."

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
	# Two large slow threats arrive together from one edge. They are intentionally
	# much larger than normal shots so they immediately function as moving terrain.
	var side: int = 0 if flood_attack_index % 2 == 1 else 1
	var lane_a: float = rng.randf_range(0.18, 0.40)
	var lane_b: float = rng.randf_range(0.60, 0.82)
	_queue_slow_projectile(side, lane_a, 108.0, 17.0, 1.02)
	_queue_slow_projectile(side, lane_b, 108.0, 17.0, 1.18)

func _queue_lingering_pressure() -> void:
	# By 12 seconds the player is already maintaining several persistent threats.
	# Fast triplets now arrive every attack so the slow blockers immediately start
	# restricting where the player can safely dodge the smaller pressure layer.
	var primary_side: int = _next_slow_side()
	var secondary_side: int = (primary_side + 1 + (flood_attack_index % 2)) % 4
	var lane_a: float = rng.randf_range(0.16, 0.84)
	var lane_b: float = _separated_lane(lane_a, 0.24)
	var lane_c: float = _separated_lane(lane_b, 0.22)

	_queue_slow_projectile(primary_side, lane_a, 110.0, 18.0, 0.96)
	_queue_slow_projectile(secondary_side, lane_b, 112.0, 18.0, 1.14)
	_queue_slow_projectile((primary_side + 2) % 4, lane_c, 112.0, 17.0, 1.34)

	var fast_side: int = (secondary_side + 2) % 4
	_queue_fast_triplet(fast_side, rng.randf_range(0.18, 0.82), 265.0, 0.74, 0.060)

	if flood_attack_index % 2 == 0:
		_queue_fast_triplet((fast_side + 1) % 4, rng.randf_range(0.18, 0.82), 265.0, 1.12, 0.055)

func _queue_mixed_attack() -> void:
	# From 22 seconds onward, slow blockers are the terrain and fast shots are the
	# immediate dodge problem. Five-shot fans are backed by a perpendicular triplet,
	# making each safe pocket temporary without changing the level's core identity.
	var blocker_side: int = _next_slow_side()
	var blocker_lane_a: float = rng.randf_range(0.16, 0.44)
	var blocker_lane_b: float = rng.randf_range(0.56, 0.84)
	_queue_slow_projectile(blocker_side, blocker_lane_a, 114.0, 19.0, 0.90)
	_queue_slow_projectile((blocker_side + 1) % 4, blocker_lane_b, 116.0, 18.0, 1.10)

	var fast_side: int = (blocker_side + 2) % 4
	var fast_center: float = rng.randf_range(0.22, 0.78)
	_queue_fast_fan(fast_side, fast_center, 280.0, 0.72, 0.070)

	var second_fast_side: int = (fast_side + 1) % 4
	_queue_fast_triplet(second_fast_side, rng.randf_range(0.16, 0.84), 280.0, 1.08, 0.060)

func _queue_pressure_attack() -> void:
	# Hard state: several large persistent blockers are already crossing while each
	# new beat fills more of the remaining lanes with small fast projectile clusters.
	var pattern: int = (flood_attack_index - 1) % 4

	if pattern == 0:
		_queue_cross_blockers(118.0, 20.0, 0.84)
		var extra_side: int = _next_slow_side()
		_queue_slow_projectile(extra_side, rng.randf_range(0.20, 0.80), 118.0, 19.0, 1.06)
		_queue_fast_crossfire(300.0, 0.66, 0.24)
	elif pattern == 1:
		var side: int = _next_slow_side()
		_queue_slow_projectile(side, rng.randf_range(0.14, 0.36), 120.0, 20.0, 0.82)
		_queue_slow_projectile(side, rng.randf_range(0.42, 0.62), 120.0, 18.0, 1.00)
		_queue_slow_projectile(side, rng.randf_range(0.66, 0.86), 120.0, 20.0, 1.18)
		_queue_fast_fan((side + 2) % 4, rng.randf_range(0.24, 0.76), 300.0, 0.64, 0.070)
		_queue_fast_triplet((side + 1) % 4, rng.randf_range(0.18, 0.82), 300.0, 1.02, 0.055)
	elif pattern == 2:
		_queue_cross_blockers(120.0, 20.0, 0.80)
		_queue_cross_blockers(122.0, 18.0, 1.16)
		var fast_side: int = rng.randi_range(0, 3)
		_queue_fast_fan(fast_side, rng.randf_range(0.22, 0.78), 300.0, 0.62, 0.068)
		_queue_fast_triplet((fast_side + 1) % 4, rng.randf_range(0.18, 0.82), 300.0, 0.98, 0.055)
	else:
		var blocker_side: int = _next_slow_side()
		_queue_slow_projectile(blocker_side, rng.randf_range(0.18, 0.82), 120.0, 21.0, 0.80)
		_queue_slow_projectile((blocker_side + 1) % 4, rng.randf_range(0.18, 0.82), 120.0, 19.0, 1.04)
		_queue_fast_crossfire(300.0, 0.62, 0.20)
		_queue_fast_triplet((blocker_side + 2) % 4, rng.randf_range(0.16, 0.84), 300.0, 1.00, 0.055)

func _queue_final_attack() -> void:
	# Final phase escalates the already-established flood. Fast attacks stay at the
	# existing 315 px/s jump, but their quantity rises sharply so movement corridors
	# are carved by the interaction between persistent blockers and fast clusters.
	var pattern: int = (flood_attack_index - 1) % 3

	if pattern == 0:
		_queue_cross_blockers(124.0, 22.0, 0.76)
		_queue_slow_projectile(_next_slow_side(), rng.randf_range(0.18, 0.82), 124.0, 20.0, 1.00)
		_queue_fast_crossfire(315.0, 0.56, 0.18)
		_queue_fast_fan(rng.randi_range(0, 3), rng.randf_range(0.22, 0.78), 315.0, 0.96, 0.062)
	elif pattern == 1:
		var side_a: int = _next_slow_side()
		var side_b: int = (side_a + 1) % 4
		_queue_slow_projectile(side_a, rng.randf_range(0.16, 0.38), 125.0, 22.0, 0.74)
		_queue_slow_projectile(side_a, rng.randf_range(0.62, 0.84), 125.0, 22.0, 0.98)
		_queue_slow_projectile(side_b, rng.randf_range(0.24, 0.76), 125.0, 20.0, 1.18)
		_queue_fast_fan((side_a + 2) % 4, rng.randf_range(0.20, 0.80), 315.0, 0.54, 0.062)
		_queue_fast_triplet((side_b + 2) % 4, rng.randf_range(0.16, 0.84), 315.0, 0.90, 0.052)
	else:
		# Four staggered blockers carve the arena into moving pockets while two dense
		# fast patterns force the player to keep abandoning whichever pocket opens.
		var start_side: int = _next_slow_side()
		for offset in range(4):
			var side: int = (start_side + offset) % 4
			var lane: float = rng.randf_range(0.16, 0.84)
			_queue_slow_projectile(side, lane, 125.0, 21.0, 0.72 + float(offset) * 0.18)
		_queue_fast_crossfire(315.0, 0.52, 0.17)
		_queue_fast_fan((start_side + 2) % 4, rng.randf_range(0.22, 0.78), 315.0, 0.96, 0.060)

func _queue_cross_blockers(speed: float, radius: float, delay: float) -> void:
	var horizontal_side: int = 0 if flood_attack_index % 2 == 1 else 1
	var vertical_side: int = 2 if flood_attack_index % 2 == 1 else 3
	var horizontal_lane: float = rng.randf_range(0.18, 0.82)
	var vertical_lane: float = _separated_lane(horizontal_lane, 0.22)
	_queue_slow_projectile(horizontal_side, horizontal_lane, speed, radius, delay)
	_queue_slow_projectile(vertical_side, vertical_lane, speed, radius, delay + 0.22)

func _queue_fast_crossfire(speed: float, delay: float, stagger: float) -> void:
	# Crossfire now uses small three-shot clusters on both axes rather than one
	# projectile per axis. The bullets stay slightly smaller so density restricts
	# movement without quietly inflating individual hitboxes.
	var horizontal_lane: float = rng.randf_range(0.18, 0.82)
	var vertical_lane: float = rng.randf_range(0.18, 0.82)
	var horizontal_side: int = 0 if rng.randf() < 0.5 else 1
	var vertical_side: int = 2 if rng.randf() < 0.5 else 3
	_queue_fast_triplet(horizontal_side, horizontal_lane, speed, delay, 0.055)
	_queue_fast_triplet(vertical_side, vertical_lane, speed, delay + stagger, 0.055)

func _queue_fast_triplet(side: int, center_lane: float, speed: float, delay: float, spacing: float) -> void:
	for offset in [-1, 0, 1]:
		var lane: float = clampf(center_lane + float(offset) * spacing, 0.07, 0.93)
		queue_projectile_warning(side, lane, speed, FAST_PROJECTILE_RADIUS, delay)

func _queue_fast_fan(side: int, center_lane: float, speed: float, delay: float, spacing: float) -> void:
	# Five small shots occupy a meaningful band of the arena without becoming a
	# solid wall. The goal is to narrow routes around the persistent slow blockers.
	for offset in [-2, -1, 0, 1, 2]:
		var lane: float = clampf(center_lane + float(offset) * spacing, 0.07, 0.93)
		queue_projectile_warning(side, lane, speed, FAST_PROJECTILE_RADIUS, delay)

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
			return rng.randf_range(3.15, 3.40)
		2:
			return rng.randf_range(2.80, 3.05)
		3:
			return rng.randf_range(2.45, 2.70)
		4:
			return rng.randf_range(2.15, 2.40)
		_:
			return rng.randf_range(1.95, 2.20)

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