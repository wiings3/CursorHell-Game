extends Node2D
class_name CursorHellDeadZonePylon

@export_category("Dead Zone")
@export var target_position: Vector2 = Vector2.ZERO
@export var zone_radius: float = 105.0
@export var travel_time: float = 1.10
@export var arm_time: float = 1.05
@export var active_time: float = 4.40
@export var burnout_time: float = 0.45

var phase := "travel"
var phase_time := 0.0
var start_position := Vector2.ZERO

@onready var zone_root: Node2D = $ZoneRoot
@onready var zone_fill: Polygon2D = $ZoneRoot/ZoneFill
@onready var arm_ring: Line2D = $ZoneRoot/ArmRing
@onready var active_ring: Line2D = $ZoneRoot/ActiveRing
@onready var outer_haze: Line2D = $ZoneRoot/OuterHaze
@onready var core_root: Node2D = $CoreRoot
@onready var core_glow: Polygon2D = $CoreRoot/CoreGlow
@onready var core_body: Polygon2D = $CoreRoot/CoreBody
@onready var core_hot: Polygon2D = $CoreRoot/CoreHot

func _ready() -> void:
	start_position = position
	zone_root.scale = Vector2.ONE * (zone_radius / 100.0)
	zone_root.visible = false
	_update_phase_visuals()

func _physics_process(delta: float) -> void:
	core_root.rotation += delta * 0.72
	phase_time += delta

	match phase:
		"travel":
			_update_travel()
		"arming":
			_update_arming()
		"active":
			_update_active()
		"burnout":
			_update_burnout()

func is_lethal() -> bool:
	return phase == "active"

func _update_travel() -> void:
	var progress := clampf(phase_time / maxf(travel_time, 0.001), 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	position = start_position.lerp(target_position, eased)
	var pulse := 0.78 + 0.22 * sin(progress * PI * 7.0)
	core_glow.modulate.a = clampf(pulse, 0.35, 1.0)

	if progress >= 1.0:
		position = target_position
		_set_phase("arming")

func _update_arming() -> void:
	var progress := clampf(phase_time / maxf(arm_time, 0.001), 0.0, 1.0)
	var pulse := 0.55 + 0.45 * absf(sin(progress * PI * 8.0))
	arm_ring.scale = Vector2.ONE * lerpf(1.18, 1.0, progress)
	arm_ring.modulate.a = 0.35 + 0.60 * pulse
	outer_haze.modulate.a = 0.10 + 0.12 * progress
	zone_fill.modulate.a = 0.03 + 0.07 * progress
	core_hot.modulate.a = 0.55 + 0.40 * pulse

	if progress >= 1.0:
		_set_phase("active")

func _update_active() -> void:
	var pulse := 0.72 + 0.28 * absf(sin(phase_time * 4.6))
	active_ring.modulate.a = 0.72 + 0.26 * pulse
	outer_haze.modulate.a = 0.16 + 0.10 * pulse
	zone_fill.modulate.a = 0.14 + 0.035 * pulse
	core_glow.modulate.a = 0.72 + 0.24 * pulse
	core_hot.modulate.a = 0.82 + 0.16 * pulse

	if phase_time >= active_time:
		_set_phase("burnout")

func _update_burnout() -> void:
	var progress := clampf(phase_time / maxf(burnout_time, 0.001), 0.0, 1.0)
	modulate.a = 1.0 - progress
	zone_root.scale = Vector2.ONE * (zone_radius / 100.0) * lerpf(1.0, 0.92, progress)
	if progress >= 1.0:
		queue_free()

func _set_phase(next_phase: String) -> void:
	phase = next_phase
	phase_time = 0.0
	_update_phase_visuals()

func _update_phase_visuals() -> void:
	match phase:
		"travel":
			zone_root.visible = false
			core_body.modulate.a = 0.78
			core_hot.modulate.a = 0.72
		"arming":
			zone_root.visible = true
			arm_ring.visible = true
			active_ring.visible = false
			zone_fill.visible = true
			core_body.modulate.a = 0.92
		"active":
			zone_root.visible = true
			arm_ring.visible = false
			active_ring.visible = true
			zone_fill.visible = true
			core_body.modulate.a = 1.0
		"burnout":
			arm_ring.visible = false
			active_ring.visible = true
