extends "res://scripts/levels/base_level.gd"
class_name CursorHellLevel01

const ROUND_TIME := 45.0
const COMPLETION_BONUS := 2500.0

func _get_level_number() -> int:
	return 1

func _get_round_time() -> float:
	return ROUND_TIME

func _get_completion_bonus() -> float:
	return COMPLETION_BONUS

func _get_phase() -> int:
	if elapsed < 7.0:
		return 0
	if elapsed < 20.0:
		return 1
	if elapsed < 32.0:
		return 2
	if elapsed < 40.0:
		return 3
	return 4

func _update_level_tutorial() -> void:
	match _get_phase():
		0:
			if moved_distance < 80.0:
				tutorial_label.text = "MOVE THE MOUSE\nYour character is the cursor."
			else:
				tutorial_label.text = "GOOD\nMovement is immediate. Stay inside the arena."
		1:
			tutorial_label.text = "READ THE EDGE\nOrange markers show where a projectile will enter."
		2:
			tutorial_label.text = "CHECK EVERY SIDE\nWarnings can now appear on all four edges."
		3:
			tutorial_label.text = "GRAZE = BONUS\nPass close without touching to build score."
		_:
			tutorial_label.text = "FINAL 5 SECONDS\nSmall movements. Stay calm."

func _schedule_level_projectile(current_phase: int) -> void:
	var side := 0
	var lane := 0.5
	var speed := 150.0
	var radius := 7.0
	var delay := 1.0

	if current_phase == 1:
		side = 0 if rng.randf() < 0.5 else 1
		lane = rng.randf_range(0.14, 0.86)
		speed = rng.randf_range(135.0, 155.0)
		delay = 1.15
	elif current_phase == 2:
		side = rng.randi_range(0, 3)
		lane = rng.randf_range(0.12, 0.88)
		speed = rng.randf_range(145.0, 175.0)
		delay = 1.0
	elif current_phase == 3:
		side = rng.randi_range(0, 3)
		lane = rng.randf_range(0.10, 0.90)
		speed = rng.randf_range(155.0, 188.0)
		radius = rng.randf_range(7.0, 8.0)
		delay = 0.92
	else:
		side = rng.randi_range(0, 3)
		lane = rng.randf_range(0.10, 0.90)
		speed = rng.randf_range(165.0, 195.0)
		radius = 7.5
		delay = 0.85

	# Keep Level 1 readable: avoid visually stacked near-identical lanes on the
	# same edge without making the random pattern predictable.
	for _attempt in range(3):
		if absf(lane - float(last_lane_by_side[side])) >= 0.09:
			break
		lane = rng.randf_range(0.12, 0.88)
	last_lane_by_side[side] = lane

	queue_projectile_warning(side, lane, speed, radius, delay)

func _get_spawn_interval(current_phase: int) -> float:
	match current_phase:
		1:
			return rng.randf_range(1.80, 2.10)
		2:
			return rng.randf_range(1.50, 1.75)
		3:
			return rng.randf_range(1.27, 1.47)
		_:
			return rng.randf_range(1.10, 1.28)

func _graze_enabled_for_phase(current_phase: int) -> bool:
	return current_phase >= 3

func _get_intro_title() -> String:
	return "FIRST CONTACT"

func _get_intro_subtitle() -> String:
	return "LEVEL 1 — TRAINING"

func _get_intro_body() -> String:
	return "Your character IS the cursor.\n\nMove the mouse to move.\nDodge the orange projectiles.\nSurvive for 45 seconds.\n\nWarnings show where danger will enter.\n\nCLICK TO BEGIN"

func _get_pause_subtitle() -> String:
	return "LEVEL 1 — FIRST CONTACT"

func _get_countdown_tutorial_text() -> String:
	return "GET READY\nMove the mouse and find a comfortable position."

func _get_countdown_subtitle() -> String:
	return "FIRST CONTACT"

func _get_death_title() -> String:
	return "RUN ENDED"

func _get_death_subtitle() -> String:
	return "LEVEL 1 — IMPACT"

func _get_death_body(reason: String, run_time: float, final_score: int, best_score: int) -> String:
	return "%s\n\nTIME   %s / 0:45\nSCORE  %s\nBEST   %s\n\nCLICK OR PRESS R TO RETRY" % [reason.to_upper(), _format_time(run_time), _format_score(final_score), _format_score(best_score)]

func _get_win_title() -> String:
	return "LEVEL COMPLETE"

func _get_win_subtitle() -> String:
	return "FIRST CONTACT CLEARED"

func _get_win_tutorial_text() -> String:
	return "LEVEL COMPLETE\nFIRST CONTACT CLEARED"

func _get_win_body(final_score: int, best_score: int) -> String:
	return "45 SECONDS SURVIVED\n\nCOMPLETION BONUS   +2,500\nFINAL SCORE        %s\nBEST SCORE         %s\n\nMovement, warnings, dodging and grazing learned.\n\nCLICK OR PRESS R TO PLAY AGAIN" % [_format_score(final_score), _format_score(best_score)]
