extends "res://scripts/levels/standard_dodge_level.gd"
class_name CursorHellLevel05

const ROUND_TIME := 60.0
const COMPLETION_BONUS := 4500.0

var pulse_attack_index := 0
var pulse_phase := -1

func _reset_round(start_now: bool) -> void:
	pulse_attack_index = 0
	pulse_phase = -1
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
			tutorial_label.text = "THE PULSE\nDanger now arrives in beats. Read the timing."
		1:
			tutorial_label.text = "ONE BEAT\nA whole volley fires together. Move between the lanes."
		2:
			tutorial_label.text = "CHANGE AXIS\nThe next pulse can come horizontally or vertically."
		3:
			tutorial_label.text = "TWO BEATS\nMove after the first volley. The second is already coming."
		4:
			tutorial_label.text = "KEEP THE RHYTHM\nSingle, double and simultaneous pulses now mix."
		_:
			tutorial_label.text = "FINAL TEMPO\nFaster volleys. Shorter beats. Keep moving on rhythm."

func _schedule_level_projectile(current_phase: int) -> void:
	# Each phase owns its own attack counter so the first pattern in a new lesson
	# is deliberate instead of inheriting parity from the previous section.
	if current_phase != pulse_phase:
		pulse_phase = current_phase
		pulse_attack_index = 0
	pulse_attack_index += 1

	match current_phase:
		1:
			# One synchronized horizontal volley teaches the basic pulse language.
			_queue_axis_pulse(true, 5, 225.0, 1.10, 0.0)
		2:
			# Alternate horizontal and vertical single-beat volleys. A small lane shift
			# keeps the player from solving every pulse from one comfortable pocket.
			var phase2_horizontal: bool = pulse_attack_index % 2 == 1
			var phase2_offset: float = 0.025 if pulse_attack_index % 4 < 2 else -0.025
			_queue_axis_pulse(phase2_horizontal, 6, 240.0, 1.00, phase2_offset)
		3:
			# The real timing lesson begins here: the second axis fires after the first,
			# so surviving means moving during the beat instead of waiting in one cell.
			if pulse_attack_index % 2 == 1:
				_queue_axis_pulse(true, 6, 250.0, 0.92, -0.025)
				_queue_axis_pulse(false, 6, 250.0, 1.52, 0.025)
			else:
				_queue_axis_pulse(false, 6, 250.0, 0.92, 0.025)
				_queue_axis_pulse(true, 6, 250.0, 1.52, -0.025)
		4:
			_queue_pressure_pattern()
		_:
			_queue_final_pattern()

func _queue_pressure_pattern() -> void:
	# The hard state lasts for the full 35-48 second section. Different rhythms
	# are mixed so the player has to identify the beat instead of memorizing one
	# repeating sequence.
	var pattern: int = (pulse_attack_index - 1) % 4

	if pattern == 0:
		_queue_axis_pulse(true, 7, 265.0, 0.88, -0.030)
		_queue_axis_pulse(false, 7, 265.0, 1.40, 0.030)
	elif pattern == 1:
		_queue_axis_pulse(false, 7, 265.0, 0.88, 0.030)
		_queue_axis_pulse(true, 7, 265.0, 1.40, -0.030)
	elif pattern == 2:
		# Both axes fire on the same beat, producing a brief grid of danger.
		_queue_axis_pulse(true, 7, 265.0, 0.86, 0.0)
		_queue_axis_pulse(false, 7, 265.0, 0.86, 0.0)
	else:
		# A same-axis double beat shifts the second volley into the spaces that were
		# safe for the first, forcing an intentional reposition.
		var horizontal: bool = pulse_attack_index % 2 == 0
		_queue_axis_pulse(horizontal, 7, 265.0, 0.86, -0.055)
		_queue_axis_pulse(horizontal, 7, 265.0, 1.36, 0.055)

func _queue_final_pattern() -> void:
	# Final escalation uses one sudden speed jump at 48 seconds and stays there.
	# No new rule is introduced; the established pulse rhythms simply tighten.
	var pattern: int = (pulse_attack_index - 1) % 4

	if pattern == 0:
		_queue_axis_pulse(true, 7, 280.0, 0.80, -0.040)
		_queue_axis_pulse(false, 7, 280.0, 1.22, 0.040)
		_queue_axis_pulse(true, 7, 280.0, 1.64, 0.040)
	elif pattern == 1:
		_queue_axis_pulse(false, 7, 280.0, 0.80, 0.040)
		_queue_axis_pulse(true, 7, 280.0, 1.22, -0.040)
		_queue_axis_pulse(false, 7, 280.0, 1.64, -0.040)
	elif pattern == 2:
		# Simultaneous pulse followed by a shifted simultaneous pulse.
		_queue_axis_pulse(true, 7, 280.0, 0.80, -0.045)
		_queue_axis_pulse(false, 7, 280.0, 0.80, 0.045)
		_queue_axis_pulse(true, 7, 280.0, 1.26, 0.045)
		_queue_axis_pulse(false, 7, 280.0, 1.26, -0.045)
	else:
		# A single all-axis beat acts as a short reset without lowering projectile
		# speed or returning to tutorial-level pressure.
		_queue_axis_pulse(true, 7, 280.0, 0.78, 0.0)
		_queue_axis_pulse(false, 7, 280.0, 0.78, 0.0)

func _queue_axis_pulse(horizontal: bool, lane_count: int, speed: float, delay: float, lane_offset: float) -> void:
	var radius: float = 8.0
	var divisor: int = maxi(lane_count - 1, 1)

	for index in range(lane_count):
		var t: float = float(index) / float(divisor)
		var lane: float = lerpf(0.12, 0.88, t) + lane_offset
		lane = clampf(lane, 0.07, 0.93)

		if horizontal:
			queue_projectile_warning(0, lane, speed, radius, delay)
			queue_projectile_warning(1, lane, speed, radius, delay)
		else:
			queue_projectile_warning(2, lane, speed, radius, delay)
			queue_projectile_warning(3, lane, speed, radius, delay)

func _get_spawn_interval(current_phase: int) -> float:
	match current_phase:
		1:
			return rng.randf_range(3.35, 3.65)
		2:
			return rng.randf_range(3.10, 3.35)
		3:
			return rng.randf_range(3.15, 3.40)
		4:
			return rng.randf_range(2.80, 3.05)
		_:
			return rng.randf_range(2.65, 2.90)

func _graze_enabled_for_phase(current_phase: int) -> bool:
	return current_phase > 0

func _get_intro_title() -> String:
	return "THE PULSE"

func _get_intro_subtitle() -> String:
	return "LEVEL 5 — TIMING"

func _get_intro_body() -> String:
	return "Projectiles now arrive in synchronized volleys.\n\nRead the warning pattern, then read the beat.\nMove between pulses instead of reacting too late.\nSurvive for 60 seconds.\n\nCLICK TO BEGIN"

func _get_pause_subtitle() -> String:
	return "LEVEL 5 — THE PULSE"

func _get_countdown_tutorial_text() -> String:
	return "GET READY\nWatch when the warnings fire together."

func _get_countdown_subtitle() -> String:
	return "THE PULSE"

func _get_death_title() -> String:
	return "RUN ENDED"

func _get_death_subtitle() -> String:
	return "LEVEL 5 — OFF BEAT"

func _get_death_body(reason: String, run_time: float, final_score: int, best_score: int) -> String:
	return "%s\n\nTIME   %s / 1:00\nSCORE  %s\nBEST   %s\n\nCLICK OR PRESS R TO RETRY" % [reason.to_upper(), _format_time(run_time), _format_score(final_score), _format_score(best_score)]

func _get_win_title() -> String:
	return "LEVEL COMPLETE"

func _get_win_subtitle() -> String:
	return "THE PULSE CLEARED"

func _get_win_tutorial_text() -> String:
	return "LEVEL COMPLETE\nTHE PULSE CLEARED"

func _get_win_body(final_score: int, best_score: int) -> String:
	return "60 SECONDS SURVIVED\n\nCOMPLETION BONUS   +4,500\nFINAL SCORE        %s\nBEST SCORE         %s\n\nVolley timing and movement rhythm learned.\n\n%s" % [_format_score(final_score), _format_score(best_score), _get_win_action_text()]
