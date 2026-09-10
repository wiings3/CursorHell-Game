extends "res://scripts/levels/standard_dodge_level.gd"
class_name CursorHellLevel03

const ROUND_TIME := 45.0
const COMPLETION_BONUS := 3500.0

var sweep_attack_index := 0
var sweep_phase := -1

func _reset_round(start_now: bool) -> void:
	sweep_attack_index = 0
	sweep_phase = -1
	super._reset_round(start_now)

func _get_level_number() -> int:
	return 3

func _get_round_time() -> float:
	return ROUND_TIME

func _get_completion_bonus() -> float:
	return COMPLETION_BONUS

func _get_phase() -> int:
	if elapsed < 6.0:
		return 0
	if elapsed < 17.0:
		return 1
	if elapsed < 28.0:
		return 2
	if elapsed < 38.0:
		return 3
	return 4

func _update_level_tutorial() -> void:
	match _get_phase():
		0:
			tutorial_label.text = "THE SWEEP\nWatch the order of the warnings, not just the lanes."
		1:
			tutorial_label.text = "STAY AHEAD\nThe pattern travels top to bottom. Move around it."
		2:
			tutorial_label.text = "READ DIRECTION\nSweeps can reverse or enter from the opposite edge."
		3:
			tutorial_label.text = "EVERY EDGE\nThe same pattern can travel horizontally or vertically."
		_:
			tutorial_label.text = "CROSSING SWEEPS\nRead where each pattern is going before you commit."

func _schedule_level_projectile(current_phase: int) -> void:
	# Give every phase its own clean rhythm so the first sweep of a new lesson is
	# intentional and does not depend on how many attacks fit in the last phase.
	if current_phase != sweep_phase:
		sweep_phase = current_phase
		sweep_attack_index = 0
	sweep_attack_index += 1

	match current_phase:
		1:
			# First lesson: one obvious top-to-bottom sweep from the left edge.
			_queue_sweep(0, true, 5, 138.0, 152.0, 1.12, 0.26, 0.16, 0.84)
		2:
			# Alternate left/right entry and reverse the lane order every attack.
			var phase2_side: int = 0 if sweep_attack_index % 2 == 1 else 1
			var phase2_ascending: bool = sweep_attack_index % 2 == 1
			_queue_sweep(phase2_side, phase2_ascending, 5, 146.0, 164.0, 1.04, 0.23, 0.14, 0.86)
		3:
			# Cycle around all four edges. Horizontal entry edges sweep through Y;
			# vertical entry edges sweep through X, teaching the same rule on both axes.
			var phase3_sides: Array[int] = [0, 2, 1, 3]
			var phase3_side: int = phase3_sides[(sweep_attack_index - 1) % phase3_sides.size()]
			var phase3_ascending: bool = sweep_attack_index % 2 == 1
			_queue_sweep(phase3_side, phase3_ascending, 6, 155.0, 174.0, 0.98, 0.19, 0.13, 0.87)
		_:
			# Finale: two perpendicular sweeps overlap briefly. They are offset enough
			# that the player can read both patterns instead of facing a solid wall.
			if sweep_attack_index % 2 == 1:
				_queue_sweep(0, true, 5, 164.0, 182.0, 0.92, 0.20, 0.14, 0.86)
				_queue_sweep(2, true, 5, 162.0, 180.0, 1.55, 0.19, 0.14, 0.86)
			else:
				_queue_sweep(1, false, 5, 164.0, 182.0, 0.92, 0.20, 0.14, 0.86)
				_queue_sweep(3, false, 5, 162.0, 180.0, 1.55, 0.19, 0.14, 0.86)

func _queue_sweep(side: int, ascending: bool, count: int, speed_min: float, speed_max: float, base_delay: float, step_delay: float, lane_min: float, lane_max: float) -> void:
	# One speed per sweep makes the attack read as a coherent moving pattern.
	# Equal lane spacing deliberately leaves generous gaps; the challenge is
	# predicting the sweep, not threading an unavoidable projectile wall.
	var speed := rng.randf_range(speed_min, speed_max)
	var radius := 7.0
	var divisor := maxi(count - 1, 1)

	for index in range(count):
		var t := float(index) / float(divisor)
		if not ascending:
			t = 1.0 - t
		var lane := lerpf(lane_min, lane_max, t)
		var delay := base_delay + float(index) * step_delay
		queue_projectile_warning(side, lane, speed, radius, delay)

func _get_spawn_interval(current_phase: int) -> float:
	match current_phase:
		1:
			return rng.randf_range(3.35, 3.65)
		2:
			return rng.randf_range(3.05, 3.30)
		3:
			return rng.randf_range(2.75, 3.00)
		_:
			return rng.randf_range(3.15, 3.35)

func _graze_enabled_for_phase(current_phase: int) -> bool:
	return current_phase > 0

func _get_intro_title() -> String:
	return "THE SWEEP"

func _get_intro_subtitle() -> String:
	return "LEVEL 3 — PATTERN"

func _get_intro_body() -> String:
	return "Warnings now form moving patterns.\n\nWatch the order they appear along an edge.\nStay ahead of the sweep or slip behind it.\nSurvive for 45 seconds.\n\nCLICK TO BEGIN"

func _get_pause_subtitle() -> String:
	return "LEVEL 3 — THE SWEEP"

func _get_countdown_tutorial_text() -> String:
	return "GET READY\nWatch the sequence along the edge."

func _get_countdown_subtitle() -> String:
	return "THE SWEEP"

func _get_death_title() -> String:
	return "RUN ENDED"

func _get_death_subtitle() -> String:
	return "LEVEL 3 — CAUGHT IN THE SWEEP"

func _get_death_body(reason: String, run_time: float, final_score: int, best_score: int) -> String:
	return "%s\n\nTIME   %s / 0:45\nSCORE  %s\nBEST   %s\n\nCLICK OR PRESS R TO RETRY" % [reason.to_upper(), _format_time(run_time), _format_score(final_score), _format_score(best_score)]

func _get_win_title() -> String:
	return "LEVEL COMPLETE"

func _get_win_subtitle() -> String:
	return "THE SWEEP CLEARED"

func _get_win_tutorial_text() -> String:
	return "LEVEL COMPLETE\nTHE SWEEP CLEARED"

func _get_win_body(final_score: int, best_score: int) -> String:
	return "45 SECONDS SURVIVED\n\nCOMPLETION BONUS   +3,500\nFINAL SCORE        %s\nBEST SCORE         %s\n\nSweep direction and moving patterns learned.\n\n%s" % [_format_score(final_score), _format_score(best_score), _get_win_action_text()]
