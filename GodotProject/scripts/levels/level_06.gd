extends "res://scripts/levels/standard_dodge_level.gd"
class_name CursorHellLevel06

const ROUND_TIME := 60.0
const COMPLETION_BONUS := 5000.0

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
			tutorial_label.text = "THE FLOOD\nSome threats do not leave quickly."
		1:
			tutorial_label.text = "LINGERING DANGER\nSlow projectiles stay in the arena. Route around them."
		2:
			tutorial_label.text = "SPACE DISAPPEARS\nMore slow threats enter before the old ones are gone."
		3:
			tutorial_label.text = "TWO SPEEDS\nFast shots now cut through the space between blockers."
		4:
			tutorial_label.text = "THE FLOOD\nOld danger stays. New danger keeps coming."
		_:
			tutorial_label.text = "NO ROOM\nDense blockers and faster shots. Keep finding space."

func _schedule_level_projectile(current_phase: int) -> void:
	if current_phase != flood_phase:
		flood_phase = current_phase
		flood_attack_index = 0
		last_slow_side = -1
	flood_attack_index += 1

	match current_phase:
		1:
			_queue_intro_blocker()
		2:
			_queue_lingering_pair()
		3:
			_queue_mixed_attack()
		4:
			_queue_pressure_attack()
		_:
			_queue_final_attack()

func _queue_intro_blocker() -> void:
	# The first section teaches the level with one large, slow projectile at a time.
	# At ~105 px/s it remains in the arena for most of the interval before the next
	# one arrives, but still exits before Projectile's existing 10-second max age.
	var side: int = 0 if flood_attack_index % 2 == 1 else 1
	var lane: float = rng.randf_range(0.18, 0.82)
	_queue_slow_projectile(side, lane, 105.0, 12.0, 1.12)

func _queue_lingering_pair() -> void:
	# Two slow threats enter from different directions. Keep their lanes separated
	# from the extreme edges so they meaningfully divide the usable arena.
	var primary_side: int = _next_slow_side()
	var secondary_side: int = (primary_side + 2) % 4
	var primary_lane: float = rng.randf_range(0.18, 0.82)
	var secondary_lane: float = _separated_lane(primary_lane, 0.24)

	_queue_slow_projectile(primary_side, primary_lane, 110.0, 12.0, 1.05)
	_queue_slow_projectile(secondary_side, secondary_lane, 112.0, 12.0, 1.30)

func _queue_mixed_attack() -> void:
	# From 23 seconds onward, lingering blockers are the terrain while normal-speed
	# projectiles create immediate dodge pressure through the remaining space.
	var blocker_side: int = _next_slow_side()
	var blocker_lane: float = rng.randf_range(0.16, 0.84)
	_queue_slow_projectile(blocker_side, blocker_lane, 115.0, 12.5, 1.00)

	var fast_side: int = (blocker_side + 1 + (flood_attack_index % 2) * 2) % 4
	var fast_lane: float = _separated_lane(blocker_lane, 0.20)
	queue_projectile_warning(fast_side, fast_lane, 255.0, 8.0, 0.82)

	if flood_attack_index % 2 == 0:
		var second_fast_side: int = (fast_side + 2) % 4
		var second_fast_lane: float = _separated_lane(fast_lane, 0.26)
		queue_projectile_warning(second_fast_side, second_fast_lane, 255.0, 8.0, 1.16)

func _queue_pressure_attack() -> void:
	# The hard state mixes several shapes rather than introducing a new mechanic.
	# The difficulty comes from navigating around threats that survived earlier beats.
	var pattern: int = (flood_attack_index - 1) % 4

	if pattern == 0:
		_queue_cross_blockers(118.0, 12.5, 0.92)
		_queue_fast_crossfire(270.0, 0.78, 0.34)
	elif pattern == 1:
		var side: int = _next_slow_side()
		var lane_a: float = rng.randf_range(0.16, 0.42)
		var lane_b: float = rng.randf_range(0.58, 0.84)
		_queue_slow_projectile(side, lane_a, 120.0, 13.0, 0.90)
		_queue_slow_projectile(side, lane_b, 120.0, 13.0, 1.18)
		queue_projectile_warning((side + 2) % 4, rng.randf_range(0.22, 0.78), 270.0, 8.0, 0.76)
	elif pattern == 2:
		_queue_cross_blockers(120.0, 13.0, 0.88)
		var fast_side: int = rng.randi_range(0, 3)
		queue_projectile_warning(fast_side, rng.randf_range(0.14, 0.86), 270.0, 8.0, 0.74)
		queue_projectile_warning((fast_side + 2) % 4, rng.randf_range(0.14, 0.86), 270.0, 8.0, 1.08)
	else:
		var blocker_side: int = _next_slow_side()
		_queue_slow_projectile(blocker_side, rng.randf_range(0.20, 0.80), 120.0, 13.0, 0.90)
		_queue_fast_crossfire(270.0, 0.76, 0.28)

func _queue_final_attack() -> void:
	# At 48 seconds the fast layer jumps once to 295 px/s. The slow layer remains
	# genuinely slow so the level keeps its identity instead of becoming Pulse 2.
	var pattern: int = (flood_attack_index - 1) % 3

	if pattern == 0:
		_queue_cross_blockers(125.0, 13.5, 0.82)
		_queue_fast_crossfire(295.0, 0.68, 0.26)
		queue_projectile_warning(rng.randi_range(0, 3), rng.randf_range(0.16, 0.84), 295.0, 8.0, 1.05)
	elif pattern == 1:
		var side_a: int = _next_slow_side()
		var side_b: int = (side_a + 1) % 4
		var lane_a: float = rng.randf_range(0.18, 0.82)
		var lane_b: float = _separated_lane(lane_a, 0.28)
		_queue_slow_projectile(side_a, lane_a, 125.0, 13.5, 0.80)
		_queue_slow_projectile(side_b, lane_b, 125.0, 13.5, 1.04)
		queue_projectile_warning((side_a + 2) % 4, rng.randf_range(0.12, 0.88), 295.0, 8.0, 0.66)
		queue_projectile_warning((side_b + 2) % 4, rng.randf_range(0.12, 0.88), 295.0, 8.0, 0.94)
	else:
		# Three staggered blockers briefly carve the arena into awkward pockets while
		# one fast crossfire pair forces the player to abandon whichever pocket felt safe.
		var start_side: int = _next_slow_side()
		for offset in range(3):
			var side: int = (start_side + offset) % 4
			var lane: float = rng.randf_range(0.18, 0.82)
			_queue_slow_projectile(side, lane, 125.0, 13.5, 0.78 + float(offset) * 0.22)
		_queue_fast_crossfire(295.0, 0.64, 0.24)

func _queue_cross_blockers(speed: float, radius: float, delay: float) -> void:
	var horizontal_side: int = 0 if flood_attack_index % 2 == 1 else 1
	var vertical_side: int = 2 if flood_attack_index % 2 == 1 else 3
	var horizontal_lane: float = rng.randf_range(0.20, 0.80)
	var vertical_lane: float = _separated_lane(horizontal_lane, 0.22)
	_queue_slow_projectile(horizontal_side, horizontal_lane, speed, radius, delay)
	_queue_slow_projectile(vertical_side, vertical_lane, speed, radius, delay + 0.26)

func _queue_fast_crossfire(speed: float, delay: float, stagger: float) -> void:
	var horizontal_lane: float = rng.randf_range(0.15, 0.85)
	var vertical_lane: float = rng.randf_range(0.15, 0.85)
	var horizontal_side: int = 0 if rng.randf() < 0.5 else 1
	var vertical_side: int = 2 if rng.randf() < 0.5 else 3
	queue_projectile_warning(horizontal_side, horizontal_lane, speed, 8.0, delay)
	queue_projectile_warning(vertical_side, vertical_lane, speed, 8.0, delay + stagger)

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
			return rng.randf_range(4.30, 4.60)
		2:
			return rng.randf_range(3.70, 4.00)
		3:
			return rng.randf_range(3.15, 3.45)
		4:
			return rng.randf_range(2.80, 3.10)
		_:
			return rng.randf_range(2.55, 2.85)

func _graze_enabled_for_phase(current_phase: int) -> bool:
	return current_phase > 0

func _get_intro_title() -> String:
	return "THE FLOOD"

func _get_intro_subtitle() -> String:
	return "LEVEL 6 — PERSISTENCE"

func _get_intro_body() -> String:
	return "Not every threat leaves quickly.\n\nSlow projectiles linger and steal space while faster attacks keep coming.\nDo not only read what is entering. Remember what is already inside.\nSurvive for 60 seconds.\n\nCLICK TO BEGIN"

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
