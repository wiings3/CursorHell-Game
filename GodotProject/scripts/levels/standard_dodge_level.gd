extends "res://scripts/levels/base_level.gd"
class_name CursorHellStandardDodgeLevel

# Shared anti-camping rule for normal dodge levels. Once hazards are active,
# staying within the same small area for too long arms a targeted pressure shot.
# The shot is deferred until the level-authored danger has fully cleared, so a
# player is never punished for correctly holding a safe lane or opening.
# If dense authored danger prevents that shot from safely releasing for too long,
# survival time and passive score stop advancing until the player relocates.
const CAMP_HOLD_TIME := 1.0
const CAMP_ESCAPE_DISTANCE := 65.0
const CAMP_PRESSURE_COOLDOWN := 2.4
const CAMP_WARNING_DELAY := 1.05
const CAMP_PRESSURE_RADIUS := 7.0
const CAMP_PRESSURE_SPEED_MIN := 165.0
const CAMP_PRESSURE_SPEED_MAX := 185.0
const CAMP_LULL_GRACE_TIME := 0.5
const CAMP_PROGRESS_STALL_DELAY := 1.75

var camp_hold_time := 0.0
var camp_pressure_cooldown := 0.0
var camp_anchor_position := Vector2.ZERO
var next_camp_shot_horizontal := true
var camp_pressure_ready := false
var camp_lull_clear_time := 0.0
var camp_pressure_wait_time := 0.0
var camp_progress_blocked := false

func _physics_process(delta: float) -> void:
	# BaseLevel still owns the trusted runtime systems. When anti-camp fallback is
	# already active, remember that state so we can remove only this frame's normal
	# survival-time/passive-score gain after BaseLevel has processed the hazards.
	# Projectile movement, warning timing, collision and graze bonuses remain live.
	var progress_was_blocked := camp_progress_blocked
	super._physics_process(delta)

	if progress_was_blocked and state == "playing":
		elapsed = maxf(0.0, elapsed - delta)
		time_left = maxf(0.0, _get_round_time() - elapsed)
		score = maxf(0.0, score - delta * 10.0)
		_update_ui()

	if state != "playing":
		_reset_camp_tracking()
		return

	# Intro/tutorial phases deliberately remain safe. The anti-camp rule only
	# begins once the level itself has entered an active hazard phase.
	if _get_phase() <= 0:
		_reset_camp_tracking()
		return

	_update_camp_pressure(delta)

	# Reuse the existing tutorial readout rather than adding another HUD element.
	# BaseLevel refreshes the normal level tutorial every frame, so as soon as the
	# player relocates and the stall clears, the level-specific text returns.
	if camp_progress_blocked:
		tutorial_label.text = "ANTI-CAMP ACTIVE\nMOVE TO RESUME TIME + SCORE"

func _reset_round(start_now: bool) -> void:
	camp_hold_time = 0.0
	camp_pressure_cooldown = 0.0
	next_camp_shot_horizontal = true
	camp_pressure_ready = false
	camp_lull_clear_time = 0.0
	camp_pressure_wait_time = 0.0
	camp_progress_blocked = false
	super._reset_round(start_now)
	camp_anchor_position = player.position

func _reset_camp_tracking() -> void:
	camp_hold_time = 0.0
	camp_pressure_ready = false
	camp_lull_clear_time = 0.0
	camp_pressure_wait_time = 0.0
	camp_progress_blocked = false
	camp_anchor_position = player.position

func _update_camp_pressure(delta: float) -> void:
	camp_pressure_cooldown = maxf(0.0, camp_pressure_cooldown - delta)

	# While the pressure shot is on cooldown, keep moving the anchor with the
	# player. When the cooldown ends they receive a fresh one-second test from
	# wherever they currently are.
	if camp_pressure_cooldown > 0.0:
		camp_hold_time = 0.0
		camp_pressure_ready = false
		camp_lull_clear_time = 0.0
		camp_pressure_wait_time = 0.0
		camp_progress_blocked = false
		camp_anchor_position = player.position
		return

	# The timer is tied to an AREA, not frame-to-frame motion. Wiggling a few
	# pixels, drawing tiny circles, or otherwise moving inside this radius does
	# not count as escaping the camp position. A real relocation also clears any
	# armed pressure and immediately resumes survival progress.
	if player.position.distance_to(camp_anchor_position) > CAMP_ESCAPE_DISTANCE:
		camp_anchor_position = player.position
		camp_hold_time = 0.0
		camp_pressure_ready = false
		camp_lull_clear_time = 0.0
		camp_pressure_wait_time = 0.0
		camp_progress_blocked = false
		return

	# Stationary time can build while the authored attack is happening, but it
	# only ARMS the anti-camp response. It does not immediately add another hazard.
	if not camp_pressure_ready:
		camp_hold_time += delta
		if camp_hold_time >= CAMP_HOLD_TIME:
			camp_hold_time = CAMP_HOLD_TIME
			camp_pressure_ready = true
			camp_pressure_wait_time = 0.0

	if not camp_pressure_ready:
		return

	# Never release anti-camp pressure while a warning is visible or a projectile
	# is still crossing the arena. This keeps authored safe lanes genuinely safe.
	# However, continuously dense levels can no longer suppress anti-camp forever:
	# after a short additional wait, survival time/passive score are suspended.
	if _has_active_level_danger():
		camp_lull_clear_time = 0.0
		camp_pressure_wait_time += delta
		if camp_pressure_wait_time >= CAMP_PROGRESS_STALL_DELAY:
			camp_progress_blocked = true
		return

	# Require a short uninterrupted lull after all danger clears. If progress was
	# already stalled, it remains stalled through this grace window and resumes as
	# soon as the pressure shot is safely released (or the player relocates).
	camp_lull_clear_time += delta
	if camp_lull_clear_time < CAMP_LULL_GRACE_TIME:
		return

	_queue_camp_pressure_shot()
	camp_hold_time = 0.0
	camp_pressure_ready = false
	camp_lull_clear_time = 0.0
	camp_pressure_wait_time = 0.0
	camp_progress_blocked = false
	camp_pressure_cooldown = CAMP_PRESSURE_COOLDOWN
	camp_anchor_position = player.position
	next_camp_shot_horizontal = not next_camp_shot_horizontal

func _has_active_level_danger() -> bool:
	# A pending anti-camp warning is only ever created after this check succeeds,
	# so any warning seen while pressure is merely armed belongs to the level.
	if not warnings.is_empty():
		return true

	for child in projectile_layer.get_children():
		var bullet := child as CursorHellProjectile
		if bullet == null or not is_instance_valid(bullet) or bullet.is_queued_for_deletion():
			continue
		return true

	return false

func _queue_camp_pressure_shot() -> void:
	# Aim at the player's CURRENT lane when the warning appears. The projectile
	# does not track afterward, so moving during the warning remains the counter.
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

	# Tag the warning as system pressure. The base projectile pipeline remains
	# untouched; the tag is copied onto the spawned bullet below for future levels
	# that may want to distinguish authored hazards from anti-camp pressure.
	var warning_index := warnings.size() - 1
	if warning_index >= 0:
		var warning: Dictionary = warnings[warning_index]
		warning["pressure_source"] = "anti_camp"

func _release_warning(warning: Dictionary) -> void:
	var child_count_before := projectile_layer.get_child_count()
	super._release_warning(warning)

	if str(warning.get("pressure_source", "")) != "anti_camp":
		return
	if projectile_layer.get_child_count() <= child_count_before:
		return

	var spawned := projectile_layer.get_child(projectile_layer.get_child_count() - 1)
	if spawned != null:
		spawned.set_meta("pressure_source", "anti_camp")
