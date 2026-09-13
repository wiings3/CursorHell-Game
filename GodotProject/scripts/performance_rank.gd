extends RefCounted
class_name CursorHellPerformanceRank

# Ranking is deliberately derived from systems the player already controls:
# survival and graze score. It never changes gameplay rules or grants power.
# A clear with zero grazing is a C. Higher ranks require deliberately playing
# close enough to danger to build additional graze score.

const SURVIVAL_WEIGHT := 70.0
const GRAZE_WEIGHT := 30.0
const GRAZE_TARGET_PER_SECOND := 45.0
const MIN_GRAZE_TARGET := 1000.0

static func evaluate(
	completed: bool,
	run_time: float,
	round_time: float,
	final_score: int,
	completion_bonus: int = 0
) -> Dictionary:
	var safe_round_time := maxf(round_time, 0.001)
	var clamped_time := clampf(run_time, 0.0, safe_round_time)
	var survival_ratio := clampf(clamped_time / safe_round_time, 0.0, 1.0)

	# BaseLevel awards 10 score per second. Everything above survival score and,
	# on clears, the completion bonus is score earned from grazing.
	var survival_score := int(floor(clamped_time * 10.0))
	var clear_bonus := completion_bonus if completed else 0
	var graze_bonus := maxi(0, final_score - survival_score - clear_bonus)
	var graze_target := maxf(MIN_GRAZE_TARGET, safe_round_time * GRAZE_TARGET_PER_SECOND)
	var graze_ratio := clampf(float(graze_bonus) / graze_target, 0.0, 1.0)

	var performance_points := roundi(
		survival_ratio * SURVIVAL_WEIGHT
		+ graze_ratio * GRAZE_WEIGHT
	)
	performance_points = clampi(performance_points, 0, 100)

	return {
		"rank": _rank_for_points(completed, performance_points),
		"points": performance_points,
		"survival_percent": clampi(roundi(survival_ratio * 100.0), 0, 100),
		"graze_bonus": graze_bonus,
		"graze_target": int(round(graze_target))
	}

static func _rank_for_points(completed: bool, points: int) -> String:
	if completed:
		# Surviving is mandatory for the mastery ranks. A clean survival with no
		# grazing starts at C; S+ requires essentially maxing the performance meter.
		if points >= 99:
			return "S+"
		if points >= 94:
			return "S"
		if points >= 86:
			return "A"
		if points >= 78:
			return "B"
		return "C"

	# Failed attempts still get useful feedback, but cannot earn A/S ranks.
	if points >= 65:
		return "B"
	if points >= 50:
		return "C"
	if points >= 30:
		return "D"
	return "F"
