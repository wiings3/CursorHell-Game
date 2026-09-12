extends "res://scripts/projectile.gd"
class_name CursorHellDisplacementZone

@export_category("Timing")
@export var warning_time: float = 2.2
@export var active_time: float = 0.70
@export var fade_time: float = 0.28

@export_category("Zone")
@export var zone_radius: float = 64.0

var phase := "warning"
var phase_time := 0.0

@onready var warning_root: Node2D = $VisualRoot/WarningRoot
@onready var warning_fill: Polygon2D = $VisualRoot/WarningRoot/WarningFill
@onready var outer_ring: Line2D = $VisualRoot/WarningRoot/OuterRing
@onready var inner_ring: Line2D = $VisualRoot/WarningRoot/InnerRing
@onready var core_ring: Line2D = $VisualRoot/WarningRoot/CoreRing
@onready var bracket_root: Node2D = $VisualRoot/WarningRoot/Brackets
@onready var active_root: Node2D = $VisualRoot/ActiveRoot
@onready var active_fill: Polygon2D = $VisualRoot/ActiveRoot/ActiveFill
@onready var active_ring: Line2D = $VisualRoot/ActiveRoot/ActiveRing
@onready var shock_ring: Line2D = $VisualRoot/ActiveRoot/ShockRing

func _ready() -> void:
	previous_position = position
	radius = -1000.0
	var radius_scale := zone_radius / 64.0
	warning_root.scale = Vector2.ONE * radius_scale
	active_root.scale = Vector2.ONE * radius_scale
	warning_root.visible = true
	active_root.visible = false

func _physics_process(delta: float) -> void:
	age += delta
	previous_position = position
	phase_time += delta
	match phase:
		"warning":
			_update_warning(delta)
		"active":
			_update_active()
		"fade":
			_update_fade(delta)

func _update_warning(delta: float) -> void:
	var progress := clampf(phase_time / maxf(warning_time, 0.001), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * absf(sin(phase_time * 12.0))
	outer_ring.scale = Vector2.ONE * lerpf(1.24, 1.0, progress)
	inner_ring.scale = Vector2.ONE * lerpf(0.82, 1.0, progress)
	core_ring.scale = Vector2.ONE * lerpf(0.58, 0.96, progress)
	bracket_root.rotation += 0.55 * delta
	warning_fill.modulate.a = lerpf(0.05, 0.18, progress) + pulse * 0.04
	outer_ring.modulate.a = 0.42 + 0.42 * progress
	inner_ring.modulate.a = 0.45 + 0.40 * pulse
	core_ring.modulate.a = 0.30 + 0.55 * progress
	if progress >= 1.0:
		_set_phase("active")

func _update_active() -> void:
	var progress := clampf(phase_time / maxf(active_time, 0.001), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * absf(sin(phase_time * 18.0))
	active_fill.modulate.a = 0.42 + pulse * 0.12
	active_ring.modulate.a = 0.82 + pulse * 0.18
	shock_ring.scale = Vector2.ONE * lerpf(0.84, 1.18, progress)
	shock_ring.modulate.a = 1.0 - progress * 0.68
	if progress >= 1.0:
		_set_phase("fade")

func _update_fade(delta: float) -> void:
	var progress := clampf(phase_time / maxf(fade_time, 0.001), 0.0, 1.0)
	modulate.a = 1.0 - progress
	active_root.scale *= 1.0 + delta * 0.18
	if progress >= 1.0:
		queue_free()

func _set_phase(next_phase: String) -> void:
	phase = next_phase
	phase_time = 0.0
	match phase:
		"warning":
			radius = -1000.0
			warning_root.visible = true
			active_root.visible = false
		"active":
			radius = zone_radius
			warning_root.visible = false
			active_root.visible = true
		"fade":
			radius = -1000.0
			warning_root.visible = false
			active_root.visible = true
