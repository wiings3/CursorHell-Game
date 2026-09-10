extends "res://scripts/levels/base_level.gd"
class_name CursorHellStandardDodgeLevel

# Shared anti-camping rule for normal dodge levels. Corners are still usable as
# temporary escape space, but sitting in one for too long creates a targeted,
# fully telegraphed shot from one of that corner's adjacent edges.
const CORNER_ZONE_SIZE := 80.0
const CORNER_HOLD_TIME := 1.0
const CORNER_PRESSURE_COOLDOWN := 2.4
const CORNER_WARNING_DELAY := 1.05
const CORNER_PRESSURE_RADIUS := 7.0
const CORNER_PRESSURE_SPEED_MIN := 165.0
const CORNER_PRESSURE_SPEED_MAX := 185.0

var corner_hold_time := 0.0
var corner_pressure_cooldown := 0.0
var tracked_corner := -1
var next_corner_shot_horizontal := true

func _physics_process(delta: float) -> void:
	# Preserve every existing BaseLevel system first: timing, spawning, warnings,
	# collision, scoring, death and win behavior all remain unchanged.
	super._physics_process(delta)

	if state != "playing":
		corner_hold_time = 0.0
		tracked_corner = -1
		return

	# Intro/tutorial phases deliberately remain safe. The anti-camp rule only
	# begins once the level itself has entered an active hazard phase.
	if _get_phase() <= 0:
		corner_hold_time = 0.0
		tracked_corner = -1
		return

	_update_corner_pressure(delta)

func _reset_round(start_now: bool) -> void:
	corner_hold_time = 0.0
	corner_pressure_cooldown = 0.0
	tracked_corner = -1
	next_corner_shot_horizontal = true
	super._reset_round(start_now)

func _update_corner_pressure(delta: float) -> void:
	corner_pressure_cooldown = maxf(0.0, corner_pressure_cooldown - delta)

	var corner := _get_player_corner()
	if corner < 0:
		corner_hold_time = 0.0
		tracked_corner = -1
		return

	# Moving from one corner to another must earn a fresh camping timer rather
	# than carrying progress from the previous corner.
	if corner != tracked_corner:
		tracked_corner = corner
		corner_hold_time = 0.0

	if corner_pressure_cooldown > 0.0:
		return

	corner_hold_time += delta
	if corner_hold_time < CORNER_HOLD_TIME:
		return

	_queue_corner_pressure_shot(corner)
	corner_hold_time = 0.0
	corner_pressure_cooldown = CORNER_PRESSURE_COOLDOWN
	next_corner_shot_horizontal = not next_corner_shot_horizontal

func _get_player_corner() -> int:
	var near_left := player.position.x <= ARENA.position.x + CORNER_ZONE_SIZE
	var near_right := player.position.x >= ARENA.end.x - CORNER_ZONE_SIZE
	var near_top := player.position.y <= ARENA.position.y + CORNER_ZONE_SIZE
	var near_bottom := player.position.y >= ARENA.end.y - CORNER_ZONE_SIZE

	if near_left and near_top:
		return 0 # top-left
	if near_right and near_top:
		return 1 # top-right
	if near_left and near_bottom:
		return 2 # bottom-left
	if near_right and near_bottom:
		return 3 # bottom-right
	return -1

func _queue_corner_pressure_shot(corner: int) -> void:
	# Aim at the player's CURRENT lane when the warning appears. The projectile
	# does not track afterward, so moving away during the warning is the counter.
	var x_lane := clampf((player.position.x - ARENA.position.x) / ARENA.size.x, 0.01, 0.99)
	var y_lane := clampf((player.position.y - ARENA.position.y) / ARENA.size.y, 0.01, 0.99)
	var horizontal := next_corner_shot_horizontal
	var side := 0
	var lane := y_lane

	if horizontal:
		# Fire from the horizontal edge adjacent to the occupied corner.
		side = 0 if corner == 0 or corner == 2 else 1
		lane = y_lane
	else:
		# Fire from the vertical edge adjacent to the occupied corner.
		side = 2 if corner == 0 or corner == 1 else 3
		lane = x_lane

	queue_projectile_warning(
		side,
		lane,
		rng.randf_range(CORNER_PRESSURE_SPEED_MIN, CORNER_PRESSURE_SPEED_MAX),
		CORNER_PRESSURE_RADIUS,
		CORNER_WARNING_DELAY
	)
