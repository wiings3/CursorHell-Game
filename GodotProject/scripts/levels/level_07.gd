extends "res://scripts/levels/standard_dodge_level.gd"
class_name CursorHellLevel07

const ROUND_TIME := 60.0
const COMPLETION_BONUS := 5500.0
const FAST_RADIUS := 7.0

var aftershock_attack_index := 0
var aftershock_phase := -1

func _reset_round(start_now: bool) -> void:
	aftershock_attack_index = 0
	aftershock_phase = -1
	super._reset_round(start_now)

func _get_level_number() -> int:
	return 7

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
	if elapsed < 47.0:
		return 4
	return 5

func _update_level_tutorial() -> void:
	match _get_phase():
		0:
			tutorial_label.text = "AFTERSHOCK\nThe first attack is not always the last."
		1:
			tutorial_label.text = "IT COMES BACK\nCleared lanes repeat. Do not immediately drift back."
		2:
			tutorial_label.text = "SHIFTED ECHO\nThe repeat can slide into nearby space."
		3:
			tutorial_label.text = "WATCH BOTH AXES\nOne dodge can set up the next problem."
		4:
			tutorial_label.text = "AFTERSHOCK\nPrimary. Echo. Reposition."
		_:
			tutorial_label.text = "KEEP MOVING\nEvery safe lane has a memory."

func _schedule_level_projectile(current_phase: int) -> void:
	if current_phase != aftershock_phase:
		aftershock_phase = current_phase
		aftershock_attack_index = 0
	aftershock_attack_index += 1

	match current_phase:
		1:
			_queue_simple_echo()
		2:
			_queue_shifted_echo()
		3:
			_queue_cross_echo()
		4:
			_queue_hard_echo()
		_:
			_queue_final_echo()

func _queue_simple_echo() -> void:
	# A compact three-shot lane cluster repeats from the same edge. The first
	# section teaches the one rule that defines the level: passing an attack does
	# not mean that lane can immediately be treated as safe again.
	var side: int = 0 if aftershock_attack_index % 2 == 1 else 1
	var center: float = _target_lane_for_side(side, 0.05)
	_queue_band(side, center, 3, 0.060, 285.0, 0.84)
	_queue_band(side, center, 3, 0.060, 292.0, 1.42)

func _queue_shifted_echo() -> void:
	# The echo now shifts slightly across the lane. Alternate axes so the player
	# cannot solve the section by simply hugging one horizontal or vertical band.
	var horizontal: bool = aftershock_attack_index % 2 == 1
	var side: int
	if horizontal:
		side = 0 if rng.randf() < 0.5 else 1
	else:
		side = 2 if rng.randf() < 0.5 else 3

	var center: float = _target_lane_for_side(side, 0.08)
	var shift: float = 0.050 if aftershock_attack_index % 4 < 2 else -0.050
	_queue_band(side, center, 5, 0.052, 298.0, 0.78)
	_queue_band(side, clampf(center + shift, 0.16, 0.84), 5, 0.052, 305.0, 1.30)

	if aftershock_attack_index % 2 == 0:
		var other_side: int = (side + 1) % 4
		var other_center: float = _target_lane_for_side(other_side, 0.10)
		_queue_band(other_side, other_center, 3, 0.060, 298.0, 1.02)

func _queue_cross_echo() -> void:
	# Primary and echo pressure now arrive on both axes. The secondary sequence is
	# offset in time so the player is repeatedly encouraged to leave a space, then
	# denied the easy option of returning to it.
	var side_a: int = rng.randi_range(0, 3)
	var side_b: int = _perpendicular_side(side_a)
	var center_a: float = _target_lane_for_side(side_a, 0.08)
	var center_b: float = _target_lane_for_side(side_b, 0.10)
	var shift_a: float = 0.052 if aftershock_attack_index % 2 == 0 else -0.052
	var shift_b: float = -shift_a

	_queue_band(side_a, center_a, 5, 0.050, 308.0, 0.70)
	_queue_band(side_a, clampf(center_a + shift_a, 0.14, 0.86), 5, 0.050, 315.0, 1.17)

	_queue_band(side_b, center_b, 3, 0.060, 305.0, 0.96)
	_queue_band(side_b, clampf(center_b + shift_b, 0.14, 0.86), 3, 0.060, 315.0, 1.43)

func _queue_hard_echo() -> void:
	# Hard state: established echo rules overlap. Some attacks repeat twice, some
	# reverse direction, and some cross on the perpendicular axis. Nothing here is
	# mechanically new; it is the same memory pressure with less recovery time.
	var pattern: int = (aftershock_attack_index - 1) % 4
	var side: int = rng.randi_range(0, 3)
	var center: float = _target_lane_for_side(side, 0.07)

	if pattern == 0:
		var shift: float = 0.048 if rng.randf() < 0.5 else -0.048
		_queue_band(side, center, 7, 0.043, 320.0, 0.62)
		_queue_band(side, clampf(center + shift, 0.15, 0.85), 7, 0.043, 328.0, 1.02)
		_queue_band(side, clampf(center - shift, 0.15, 0.85), 5, 0.050, 328.0, 1.40)
	elif pattern == 1:
		var opposite: int = (side + 2) % 4
		_queue_band(side, center, 7, 0.043, 320.0, 0.60)
		_queue_band(opposite, center, 7, 0.043, 328.0, 1.02)
		var cross_side: int = _perpendicular_side(side)
		_queue_band(cross_side, _target_lane_for_side(cross_side, 0.09), 5, 0.050, 320.0, 1.22)
	elif pattern == 2:
		var cross_side_a: int = _perpendicular_side(side)
		var cross_center: float = _target_lane_for_side(cross_side_a, 0.08)
		_queue_band(side, center, 5, 0.050, 322.0, 0.58)
		_queue_band(cross_side_a, cross_center, 5, 0.050, 322.0, 0.78)
		_queue_band(side, clampf(center + 0.055, 0.14, 0.86), 5, 0.050, 330.0, 1.00)
		_queue_band(cross_side_a, clampf(cross_center - 0.055, 0.14, 0.86), 5, 0.050, 330.0, 1.20)
	else:
		# A wider primary band followed by a narrower targeted echo creates a brief
		# false sense that the center of the attack has already been cleared.
		_queue_band(side, center, 9, 0.038, 320.0, 0.60)
		_queue_band(side, _target_lane_for_side(side, 0.035), 5, 0.048, 332.0, 1.00)
		var other_side: int = _perpendicular_side(side)
		_queue_band(other_side, _target_lane_for_side(other_side, 0.08), 5, 0.048, 322.0, 1.18)

func _queue_final_echo() -> void:
	# Final phase tightens the same established patterns. Fast primary volleys are
	# followed by short-delay echoes and occasional second echoes, so the player
	# must keep committing to new space instead of oscillating between two pockets.
	var pattern: int = (aftershock_attack_index - 1) % 3
	var side: int = rng.randi_range(0, 3)
	var center: float = _target_lane_for_side(side, 0.055)
	var opposite: int = (side + 2) % 4
	var cross_side: int = _perpendicular_side(side)

	if pattern == 0:
		_queue_band(side, center, 9, 0.037, 338.0, 0.52)
		_queue_band(side, clampf(center + 0.050, 0.14, 0.86), 7, 0.041, 345.0, 0.88)
		_queue_band(opposite, clampf(center - 0.050, 0.14, 0.86), 7, 0.041, 345.0, 1.24)
		_queue_band(cross_side, _target_lane_for_side(cross_side, 0.07), 5, 0.046, 338.0, 1.04)
	elif pattern == 1:
		var cross_center: float = _target_lane_for_side(cross_side, 0.055)
		_queue_band(side, center, 7, 0.041, 340.0, 0.50)
		_queue_band(cross_side, cross_center, 7, 0.041, 340.0, 0.68)
		_queue_band(side, clampf(center - 0.055, 0.14, 0.86), 7, 0.041, 348.0, 0.88)
		_queue_band(cross_side, clampf(cross_center + 0.055, 0.14, 0.86), 7, 0.041, 348.0, 1.06)
		_queue_band(opposite, _target_lane_for_side(opposite, 0.065), 5, 0.046, 348.0, 1.30)
	else:
		_queue_band(side, center, 9, 0.036, 342.0, 0.48)
		_queue_band(opposite, center, 9, 0.036, 342.0, 0.80)
		_queue_band(side, _target_lane_for_side(side, 0.035), 5, 0.045, 350.0, 1.10)
		_queue_band(cross_side, _target_lane_for_side(cross_side, 0.050), 7, 0.040, 345.0, 0.96)

func _queue_band(side: int, center_lane: float, count: int, spacing: float, speed: float, delay: float) -> void:
	var half := int(count / 2)
	for index in range(count):
		var offset_index := index - half
		var lane := clampf(center_lane + float(offset_index) * spacing, 0.06, 0.94)
		queue_projectile_warning(side, lane, speed, FAST_RADIUS, delay)

func _target_lane_for_side(side: int, jitter: float) -> float:
	var lane: float
	if side == 0 or side == 1:
		lane = (player.position.y - ARENA.position.y) / ARENA.size.y
	else:
		lane = (player.position.x - ARENA.position.x) / ARENA.size.x
	lane += rng.randf_range(-jitter, jitter)
	return clampf(lane, 0.10, 0.90)

func _perpendicular_side(side: int) -> int:
	if side == 0 or side == 1:
		return 2 if rng.randf() < 0.5 else 3
	return 0 if rng.randf() < 0.5 else 1

func _get_spawn_interval(current_phase: int) -> float:
	match current_phase:
		1:
			return rng.randf_range(2.75, 3.00)
		2:
			return rng.randf_range(2.35, 2.60)
		3:
			return rng.randf_range(2.00, 2.25)
		4:
			return rng.randf_range(1.72, 1.95)
		_:
			return rng.randf_range(1.48, 1.68)

func _graze_enabled_for_phase(current_phase: int) -> bool:
	return current_phase > 0

func _get_intro_title() -> String:
	return "AFTERSHOCK"

func _get_intro_subtitle() -> String:
	return "LEVEL 7 — MEMORY"

func _get_intro_body() -> String:
	return "The first wave is only the warning.\n\nAttacks return through the same space, then begin shifting into nearby lanes.\nDo not immediately retreat into the path you just escaped.\nSurvive for 60 seconds.\n\nCLICK TO BEGIN"

func _get_pause_subtitle() -> String:
	return "LEVEL 7 — AFTERSHOCK"

func _get_countdown_tutorial_text() -> String:
	return "GET READY\nRemember where the last attack passed."

func _get_countdown_subtitle() -> String:
	return "AFTERSHOCK"

func _get_death_title() -> String:
	return "RUN ENDED"

func _get_death_subtitle() -> String:
	return "LEVEL 7 — CAUGHT IN THE ECHO"

func _get_death_body(reason: String, run_time: float, final_score: int, best_score: int) -> String:
	return "%s\n\nTIME   %s / 1:00\nSCORE  %s\nBEST   %s\n\nCLICK OR PRESS R TO RETRY" % [reason.to_upper(), _format_time(run_time), _format_score(final_score), _format_score(best_score)]

func _get_win_title() -> String:
	return "LEVEL COMPLETE"

func _get_win_subtitle() -> String:
	return "AFTERSHOCK CLEARED"

func _get_win_tutorial_text() -> String:
	return "LEVEL COMPLETE\nAFTERSHOCK CLEARED"

func _get_win_body(final_score: int, best_score: int) -> String:
	return "60 SECONDS SURVIVED\n\nCOMPLETION BONUS   +5,500\nFINAL SCORE        %s\nBEST SCORE         %s\n\nRepeated lanes and shifting echoes survived.\n\n%s" % [_format_score(final_score), _format_score(best_score), _get_win_action_text()]
