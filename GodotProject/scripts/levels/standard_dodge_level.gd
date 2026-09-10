extends "res://scripts/levels/base_level.gd"
class_name CursorHellStandardDodgeLevel

# Shared anti-camping rule for normal dodge levels. Once hazards are active,
# staying within the same small area for too long creates a targeted, fully
# telegraphed shot through the player's current position. Small mouse wiggles
# do not reset the timer; the player has to actually relocate.
const CAMP_HOLD_TIME := 1.0
const CAMP_ESCAPE_DISTANCE := 65.0
const CAMP_PRESSURE_COOLDOWN := 2.4
const CAMP_WARNING_DELAY := 1.05
const CAMP_PRESSURE_RADIUS := 7.0
const CAMP_PRESSURE_SPEED_MIN := 165.0
const CAMP_PRESSURE_SPEED_MAX := 185.0

var camp_hold_time := 0.0
var camp_pressure_cooldown := 0.0
var camp_anchor_position := Vector2.ZERO
var next_camp_shot_horizontal := true

func _physics_process(delta: float) -> void:
	# Preserve every existing BaseLevel system first: timing, spawning, warnings,
	# collision, scoring, death and win behavior all remain unchanged.
	super._physics_process(delta)

	if state != "playing":
		_reset_camp_tracking()
		return

	# Intro/tutorial phases deliberately remain safe. The anti-camp rule only
	# begins once the level itself has entered an active hazard phase.
	if _get_phase() <= 0:
		_reset_camp_tracking()
		return

	_update_camp_pressure(delta)

func _reset_round(start_now: bool) -> void:
	camp_hold_time = 0.0
	camp_pressure_cooldown = 0.0
	next_camp_shot_horizontal = true
	super._reset_round(start_now)
	camp_anchor_position = player.position

func _reset_camp_tracking() -> void:
	camp_hold_time = 0.0
	camp_anchor_position = player.position

func _update_camp_pressure(delta: float) -> void:
	camp_pressure_cooldown = maxf(0.0, camp_pressure_cooldown - delta)

	# While the pressure shot is on cooldown, keep moving the anchor with the
	# player. When the cooldown ends they receive a fresh one-second grace window
	# from wherever they currently are.
	if camp_pressure_cooldown > 0.0:
		camp_hold_time = 0.0
		camp_anchor_position = player.position
		return

	# The timer is tied to an AREA, not frame-to-frame motion. Wiggling a few
	# pixels, drawing tiny circles, or otherwise moving inside this radius does
	# not count as escaping the camp position.
	if player.position.distance_to(camp_anchor_position) > CAMP_ESCAPE_DISTANCE:
		camp_anchor_position = player.position
		camp_hold_time = 0.0
		return

	camp_hold_time += delta
	if camp_hold_time < CAMP_HOLD_TIME:
		return

	_queue_camp_pressure_shot()
	camp_hold_time = 0.0
	camp_pressure_cooldown = CAMP_PRESSURE_COOLDOWN
	camp_anchor_position = player.position
	next_camp_shot_horizontal = not next_camp_shot_horizontal

func _queue_camp_pressure_shot() -> void:
	# Aim at the player's CURRENT lane when the warning appears. The projectile
	# does not track afterward, so moving during the warning is always the counter.
	var x_lane := clampf((player.position.x - ARENA.position.x) / ARENA.size.x, 0.01, 0.99)
	var y_lane := clampf((player.position.y - ARENA.position.y) / ARENA.size.y, 0.01, 0.99)
	var horizontal := next_camp_shot_horizontal
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
		rng.randf_range(CAMP_PRESSURE_SPEED_MIN, CAMP_PRESSURE_SPEED_MAX),
		CAMP_PRESSURE_RADIUS,
		CAMP_WARNING_DELAY
	)
