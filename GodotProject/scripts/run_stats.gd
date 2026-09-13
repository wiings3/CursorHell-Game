extends RefCounted
class_name CursorHellRunStats

# One explicit record of what happened during a single attempt. Gameplay systems
# write to this object as events happen; result/rank/save systems only read it.

var level_number: int = 0
var level_name: String = ""
var round_time: float = 0.0

var time_survived: float = 0.0
var final_score: int = 0
var graze_count: int = 0
var graze_score: int = 0
var max_graze_combo: int = 0
var anti_camp_triggers: int = 0

var completion_bonus: int = 0
var completed: bool = false
var death_reason: String = ""
var death_phase: int = -1
var death_position: Vector2 = Vector2.ZERO
var finished: bool = false

func reset(number: int, display_name: String, duration: float) -> void:
	level_number = number
	level_name = display_name
	round_time = maxf(duration, 0.0)
	time_survived = 0.0
	final_score = 0
	graze_count = 0
	graze_score = 0
	max_graze_combo = 0
	anti_camp_triggers = 0
	completion_bonus = 0
	completed = false
	death_reason = ""
	death_phase = -1
	death_position = Vector2.ZERO
	finished = false

func update_live(run_time: float, score_value: int) -> void:
	if finished:
		return
	time_survived = _clamp_run_time(run_time)
	final_score = maxi(score_value, 0)

func record_graze(bonus: int, current_combo: int) -> void:
	if finished:
		return
	graze_count += 1
	graze_score += maxi(bonus, 0)
	max_graze_combo = maxi(max_graze_combo, current_combo)

func record_anti_camp_trigger() -> void:
	if finished:
		return
	anti_camp_triggers += 1

func finish(
	did_complete: bool,
	run_time: float,
	score_value: int,
	clear_bonus: int = 0,
	reason: String = "",
	phase: int = -1,
	player_position: Vector2 = Vector2.ZERO
) -> void:
	completed = did_complete
	time_survived = _clamp_run_time(run_time)
	final_score = maxi(score_value, 0)
	completion_bonus = maxi(clear_bonus, 0) if did_complete else 0
	death_reason = "" if did_complete else reason
	death_phase = phase
	death_position = player_position
	finished = true

func survival_percent() -> int:
	if round_time <= 0.0:
		return 0
	return clampi(roundi((time_survived / round_time) * 100.0), 0, 100)

func _clamp_run_time(value: float) -> float:
	if round_time <= 0.0:
		return maxf(value, 0.0)
	return clampf(value, 0.0, round_time)
