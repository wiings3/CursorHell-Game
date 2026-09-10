extends "res://scripts/levels/base_level.gd"
class_name CursorHellStandardDodgeLevel

# Shared anti-camping rule for normal dodge levels. Once hazards are active,
# remaining effectively stationary anywhere in the arena for too long creates
# a targeted, fully telegraphed shot through the player's current position.
const STATIONARY_HOLD_TIME := 1.0
const STATIONARY_MOVEMENT_EPSILON := 0.5
const STATIONARY_PRESSURE_COOLDOWN := 2.4
const STATIONARY_WARNING_DELAY := 1.05
const STATIONARY_PRESSURE_RADIUS := 7.0
const STATIONARY_PRESSURE_SPEED_MIN := 165.0
const STATIONARY_PRESSURE_SPEED_MAX := 185.0

var stationary_hold_time := 0.0
var stationary_pressure_cooldown := 0.0
var last_stationary_position := Vector2.ZERO
var next_stationary_shot_horizontal := true

func _physics_process(delta: float) -> void:
	# Preserve every existing BaseLevel system first: timing, spawning, warnings,
	# collision, scoring, death and win behavior all remain unchanged.
	super._physics_process(delta)

	if state != "playing":
		stationary_hold_time = 0.0
		last_stationary_position = player.position
		return

	# Intro/tutorial phases deliberately remain safe. The anti-camp rule only
	# begins once the level itself has entered an active hazard phase.
	if _get_phase() <= 0:
		stationary_hold_time = 0.0
		last_stationary_position = player.position
		return

	_update_stationary_pressure(delta)

func _reset_round(start_now: bool) -> void:
	stationary_hold_time = 0.0
	stationary_pressure_cooldown = 0.0
	next_stationary_shot_horizontal = true
	super._reset_round(start_now)
	last_stationary_position = player.position

func _update_stationary_pressure(delta: float) -> void:
	stationary_pressure_cooldown = maxf(0.0, stationary_pressure_cooldown - delta)

	var moved := player.position.distance_to(last_stationary_position) > STATIONARY_MOVEMENT_EPSILON
	last_stationary_position = player.position

	if moved:
		stationary_hold_time = 0.0
		return

	# Require another full second of stillness after each pressure-shot cooldown,
	# rather than immediately firing again when the cooldown expires.
	if stationary_pressure_cooldown > 0.0:
		stationary_hold_time = 0.0
		return

	stationary_hold_time += delta
	if stationary_hold_time < STATIONARY_HOLD_TIME:
		return

	_queue_stationary_pressure_shot()
	stationary_hold_time = 0.0
	stationary_pressure_cooldown = STATIONARY_PRESSURE_COOLDOWN
	next_stationary_shot_horizontal = not next_stationary_shot_horizontal

func _queue_stationary_pressure_shot() -> void:
	# Aim at the player's CURRENT lane when the warning appears. The projectile
	# does not track afterward, so moving during the warning is always the counter.
	var x_lane := clampf((player.position.x - ARENA.position.x) / ARENA.size.x, 0.01, 0.99)
	var y_lane := clampf((player.position.y - ARENA.position.y) / ARENA.size.y, 0.01, 0.99)
	var horizontal := next_stationary_shot_horizontal
	var side := 0
	var lane := y_lane

	if horizontal:
		# Either horizontal edge can punish the current Y lane.
		side = 0 if rng.randf() < 0.5 else 1
		lane = y_lane
	else:
		# Either vertical edge can punish the current X lane.
		side = 2 if rng.randf() < 0.5 else 3
		lane = x_lane

	queue_projectile_warning(
		side,
		lane,
		rng.randf_range(STATIONARY_PRESSURE_SPEED_MIN, STATIONARY_PRESSURE_SPEED_MAX),
		STATIONARY_PRESSURE_RADIUS,
		STATIONARY_WARNING_DELAY
	)
