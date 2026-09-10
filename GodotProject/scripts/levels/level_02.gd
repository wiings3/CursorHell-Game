extends "res://scripts/levels/standard_dodge_level.gd"
class_name CursorHellLevel02

const ROUND_TIME := 45.0
const COMPLETION_BONUS := 3000.0

var crossfire_attack_index := 0
var crossfire_phase := -1

func _reset_round(start_now: bool) -> void:
	crossfire_attack_index = 0
	crossfire_phase = -1
	super._reset_round(start_now)

func _get_level_number() -> int:
	return 2

func _get_round_time() -> float:
	return ROUND_TIME

func _get_completion_bonus() -> float:
	return COMPLETION_BONUS

func _get_phase() -> int:
	if elapsed < 6.0:
		return 0
	if elapsed < 18.0:
		return 1
	if elapsed < 30.0:
		return 2
	if elapsed < 40.0:
		return 3
	return 4

func _update_level_tutorial() -> void:
	match _get_phase():
		0:
			tutorial_label.text = "CROSSFIRE\nOpposite edges now work together."
		1:
			tutorial_label.text = "OPPOSING SIDES\nRead both warnings before committing to a move."
		2:
			tutorial_label.text = "VERTICAL PAIRS\nTop and bottom are one attack. Reposition early."
		3:
			tutorial_label.text = "TWO BEATS\nSome pairs split their timing. Keep moving between shots."
		_:
			tutorial_label.text = "TRUE CROSSFIRE\nRead the open space, then read the timing."

func _schedule_level_projectile(current_phase: int) -> void:
	# Each phase owns its own attack rhythm. Resetting here makes the first attack
	# of every section intentional instead of depending on how many random-timed
	# attacks happened to fit inside the previous section.
	if current_phase != crossfire_phase:
		crossfire_phase = current_phase
		crossfire_attack_index = 0
	crossfire_attack_index += 1

	match current_phase:
		1:
			_queue_crossfire_pair(true, 132.0, 150.0, 1.20, 0.22, 0.34)
		2:
			_queue_crossfire_pair(false, 140.0, 160.0, 1.10, 0.18, 0.30)
		3:
			# Start horizontal, then alternate axes. Every second attack becomes a
			# two-beat pair so the player learns the stagger before the finale.
			var horizontal := crossfire_attack_index % 2 == 1
			var stagger := 0.0
			if crossfire_attack_index % 2 == 0:
				stagger = rng.randf_range(0.25, 0.38)
			_queue_crossfire_pair(horizontal, 150.0, 175.0, 1.00, 0.16, 0.26, stagger)
		_:
			# The finale always enters on the same readable sequence: horizontal,
			# vertical, then both axes. Stagger keeps the overlap rhythmic rather than
			# releasing four projectiles on the exact same frame.
			var pattern := (crossfire_attack_index - 1) % 3
			if pattern == 0:
				_queue_crossfire_pair(true, 160.0, 182.0, 0.95, 0.14, 0.23, rng.randf_range(0.28, 0.38))
			elif pattern == 1:
				_queue_crossfire_pair(false, 160.0, 182.0, 0.95, 0.14, 0.23, rng.randf_range(0.28, 0.38))
			else:
				_queue_crossfire_pair(true, 158.0, 178.0, 1.00, 0.16, 0.25, rng.randf_range(0.24, 0.32))
				_queue_crossfire_pair(false, 158.0, 178.0, 1.00, 0.16, 0.25, rng.randf_range(0.32, 0.40))

func _queue_crossfire_pair(horizontal: bool, speed_min: float, speed_max: float, delay: float, gap_min: float, gap_max: float, stagger: float = 0.0) -> void:
	# Build the pair around a shared center, then offset the two lanes. Keeping
	# them separated avoids cheap same-lane pinches while preserving the idea
	# that both warnings are one coordinated attack.
	var center := rng.randf_range(0.32, 0.68)
	var gap := rng.randf_range(gap_min, gap_max)
	var lane_a := clampf(center - gap * 0.5, 0.12, 0.88)
	var lane_b := clampf(center + gap * 0.5, 0.12, 0.88)
	if rng.randf() < 0.5:
		var swap := lane_a
		lane_a = lane_b
		lane_b = swap

	var speed := rng.randf_range(speed_min, speed_max)
	var radius := 7.0
	var delay_a := delay
	var delay_b := delay + stagger

	# Randomize which side gets the second beat so the rhythm is predictable but
	# the exact dodge direction is not. Both warning markers are queued now.
	if stagger > 0.0 and rng.randf() < 0.5:
		var delay_swap := delay_a
		delay_a = delay_b
		delay_b = delay_swap

	if horizontal:
		queue_projectile_warning(0, lane_a, speed, radius, delay_a)
		queue_projectile_warning(1, lane_b, speed, radius, delay_b)
	else:
		queue_projectile_warning(2, lane_a, speed, radius, delay_a)
		queue_projectile_warning(3, lane_b, speed, radius, delay_b)

func _get_spawn_interval(current_phase: int) -> float:
	match current_phase:
		1:
			return rng.randf_range(2.45, 2.80)
		2:
			return rng.randf_range(2.20, 2.55)
		3:
			return rng.randf_range(1.85, 2.10)
		_:
			return rng.randf_range(1.55, 1.75)

func _graze_enabled_for_phase(current_phase: int) -> bool:
	return current_phase > 0

func _get_intro_title() -> String:
	return "CROSSFIRE"

func _get_intro_subtitle() -> String:
	return "LEVEL 2 — COORDINATION"

func _get_intro_body() -> String:
	return "Warnings now arrive in coordinated pairs.\n\nOpposite edges fire together.\nRead both lanes before moving.\nSurvive for 45 seconds.\n\nCLICK TO BEGIN"

func _get_pause_subtitle() -> String:
	return "LEVEL 2 — CROSSFIRE"

func _get_countdown_tutorial_text() -> String:
	return "GET READY\nRead pairs as a single attack."

func _get_countdown_subtitle() -> String:
	return "CROSSFIRE"

func _get_death_title() -> String:
	return "RUN ENDED"

func _get_death_subtitle() -> String:
	return "LEVEL 2 — CAUGHT IN THE CROSS"

func _get_death_body(reason: String, run_time: float, final_score: int, best_score: int) -> String:
	return "%s\n\nTIME   %s / 0:45\nSCORE  %s\nBEST   %s\n\nCLICK OR PRESS R TO RETRY" % [reason.to_upper(), _format_time(run_time), _format_score(final_score), _format_score(best_score)]

func _get_win_title() -> String:
	return "LEVEL COMPLETE"

func _get_win_subtitle() -> String:
	return "CROSSFIRE CLEARED"

func _get_win_tutorial_text() -> String:
	return "LEVEL COMPLETE\nCROSSFIRE CLEARED"

func _get_win_body(final_score: int, best_score: int) -> String:
	return "45 SECONDS SURVIVED\n\nCOMPLETION BONUS   +3,000\nFINAL SCORE        %s\nBEST SCORE         %s\n\nOpposing lanes and coordinated attacks learned.\n\n%s" % [_format_score(final_score), _format_score(best_score), _get_win_action_text()]
