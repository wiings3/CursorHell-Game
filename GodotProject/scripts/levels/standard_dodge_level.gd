extends "res://scripts/levels/base_level.gd"
class_name CursorHellStandardDodgeLevel

const DisplacementZoneScene := preload("res://Scenes/Components/DisplacementZone.tscn")

# Standing still is valid play. Anti-camp only reacts when the player remains
# inside the same small region for a long stretch, at which point that location
# receives a short, readable displacement warning.
const CAMP_HOLD_TIME := 6.0
const CAMP_REGION_RADIUS := 80.0
const CAMP_COOLDOWN := 4.5
const CAMP_ZONE_RADIUS := 64.0
const CAMP_WARNING_TIME := 2.0
const CAMP_ACTIVE_TIME := 0.70

var camp_hold_time := 0.0
var camp_cooldown := 0.0
var camp_anchor_position := Vector2.ZERO

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if state != "playing":
		_reset_camp_tracking()
		return

	# Tutorial/opening phases remain untouched. Once authored hazards begin, the
	# player gets a generous six-second window in any one region before pressure.
	if _get_phase() <= 0:
		_reset_camp_tracking()
		return

	_update_camp_tracking(delta)

func _reset_round(start_now: bool) -> void:
	camp_hold_time = 0.0
	camp_cooldown = 0.0
	super._reset_round(start_now)
	camp_anchor_position = player.position

func _reset_camp_tracking() -> void:
	camp_hold_time = 0.0
	camp_cooldown = 0.0
	if is_instance_valid(player):
		camp_anchor_position = player.position

func _update_camp_tracking(delta: float) -> void:
	camp_cooldown = maxf(0.0, camp_cooldown - delta)

	# Cooldown is a real grace period. Follow the player during it so the next test
	# starts from wherever they actually settle afterward.
	if camp_cooldown > 0.0:
		camp_hold_time = 0.0
		camp_anchor_position = player.position
		return

	# Small adjustments and normal mouse jitter do not reset the timer. A genuine
	# relocation beyond this region starts a fresh six-second window.
	if player.position.distance_to(camp_anchor_position) > CAMP_REGION_RADIUS:
		camp_anchor_position = player.position
		camp_hold_time = 0.0
		return

	camp_hold_time += delta
	if camp_hold_time < CAMP_HOLD_TIME:
		return

	_spawn_displacement_zone(player.position)
	camp_hold_time = 0.0
	camp_cooldown = CAMP_COOLDOWN
	camp_anchor_position = player.position

func _spawn_displacement_zone(target_position: Vector2) -> void:
	var zone := DisplacementZoneScene.instantiate() as CursorHellDisplacementZone
	if zone == null:
		push_error("Cursor Hell: DisplacementZone.tscn must use CursorHellDisplacementZone.")
		return

	zone.position = target_position
	zone.zone_radius = CAMP_ZONE_RADIUS
	zone.warning_time = CAMP_WARNING_TIME
	zone.active_time = CAMP_ACTIVE_TIME
	projectile_layer.add_child(zone)
	run_stats.record_anti_camp_trigger()
