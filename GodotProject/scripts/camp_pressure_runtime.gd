extends RefCounted
class_name CursorHellCampPressureRuntime

const DisplacementZoneScene := preload("res://Scenes/Components/DisplacementZone.tscn")

const HOLD_TIME := 6.0
const REGION_RADIUS := 80.0
const COOLDOWN := 4.5
const ZONE_RADIUS := 64.0
const WARNING_TIME := 2.0
const ACTIVE_TIME := 0.70

var hold_time := 0.0
var cooldown := 0.0
var anchor_position := Vector2.ZERO

func reset(level: CursorHellBaseLevel) -> void:
	hold_time = 0.0
	cooldown = 0.0
	if is_instance_valid(level) and is_instance_valid(level.player):
		anchor_position = level.player.position

func update(level: CursorHellBaseLevel, delta: float) -> void:
	if not is_instance_valid(level) or not is_instance_valid(level.player):
		return
	if level.state != "playing" or level._get_phase() <= 0:
		reset(level)
		return

	cooldown = maxf(0.0, cooldown - delta)
	if cooldown > 0.0:
		hold_time = 0.0
		anchor_position = level.player.position
		return

	if level.player.position.distance_to(anchor_position) > REGION_RADIUS:
		anchor_position = level.player.position
		hold_time = 0.0
		return

	hold_time += delta
	if hold_time < HOLD_TIME:
		return

	_spawn_zone(level, level.player.position)
	hold_time = 0.0
	cooldown = COOLDOWN
	anchor_position = level.player.position

func _spawn_zone(level: CursorHellBaseLevel, target_position: Vector2) -> void:
	var zone := DisplacementZoneScene.instantiate() as CursorHellDisplacementZone
	if zone == null:
		return
	zone.position = target_position
	zone.zone_radius = ZONE_RADIUS
	zone.warning_time = WARNING_TIME
	zone.active_time = ACTIVE_TIME
	level.projectile_layer.add_child(zone)
	level.run_stats.record_anti_camp_trigger()
