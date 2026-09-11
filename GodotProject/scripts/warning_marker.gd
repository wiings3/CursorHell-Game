extends Node2D
class_name CursorHellWarningMarker

@onready var guide: Line2D = $Guide
@onready var edge_wide: Line2D = $EdgeWide
@onready var edge_core: Line2D = $EdgeCore
@onready var marker_body: Node2D = $MarkerBody
@onready var arrow: Polygon2D = $MarkerBody/Arrow
@onready var countdown_ring: Line2D = $MarkerBody/CountdownRing
@onready var sweep_ring: Line2D = $MarkerBody/SweepRing

var base_edge_wide_width: float = 7.0
var base_edge_core_width: float = 2.0

func _ready() -> void:
	base_edge_wide_width = edge_wide.width
	base_edge_core_width = edge_core.width

func apply_warning(warning: Dictionary, arena: Rect2) -> void:
	var side: int = int(warning.get("side", 0))
	var lane: float = float(warning.get("lane", 0.5))
	var time_left: float = float(warning.get("time", 0.0))
	var duration: float = maxf(0.001, float(warning.get("max", 1.0)))
	var progress: float = clampf(time_left / duration, 0.0, 1.0)
	var pulse: float = 0.45 + 0.55 * absf(sin((1.0 - progress) * PI * 7.0))

	var sweep_focus := 0.0
	if bool(warning.get("sweep_visual", false)):
		var focus_time: float = float(warning.get("sweep_focus_time", 0.55))
		var focus_width: float = maxf(0.05, float(warning.get("sweep_focus_width", 0.18)))
		sweep_focus = clampf(1.0 - absf(time_left - focus_time) / focus_width, 0.0, 1.0)
		if bool(warning.get("sweep_start", false)):
			sweep_focus = clampf(sweep_focus * 1.18, 0.0, 1.0)

	var guide_length := arena.size.x
	match side:
		0:
			position = Vector2(arena.position.x + 11.0, arena.position.y + arena.size.y * lane)
			rotation = 0.0
			guide_length = arena.size.x
		1:
			position = Vector2(arena.end.x - 11.0, arena.position.y + arena.size.y * lane)
			rotation = PI
			guide_length = arena.size.x
		2:
			position = Vector2(arena.position.x + arena.size.x * lane, arena.position.y + 11.0)
			rotation = PI / 2.0
			guide_length = arena.size.y
		_:
			position = Vector2(arena.position.x + arena.size.x * lane, arena.end.y - 11.0)
			rotation = -PI / 2.0
			guide_length = arena.size.y

	# Geometry/style is authored in WarningMarker.tscn. Runtime code only stretches
	# the guide to the arena and animates opacity/scale based on warning timing.
	guide.points = PackedVector2Array([Vector2(-11.0, 0.0), Vector2(guide_length - 11.0, 0.0)])
	guide.modulate.a = clampf(0.07 + 0.08 * pulse + 0.13 * sweep_focus, 0.0, 1.0)

	edge_wide.width = base_edge_wide_width + 4.0 * sweep_focus
	edge_core.width = base_edge_core_width + sweep_focus
	edge_wide.modulate.a = clampf(0.72 + 0.25 * pulse + 0.18 * sweep_focus, 0.0, 1.0)
	edge_core.modulate.a = clampf(0.72 + 0.24 * sweep_focus, 0.0, 1.0)

	var marker_scale := 1.0 + 0.28 * sweep_focus
	marker_body.scale = Vector2.ONE * marker_scale
	arrow.modulate.a = clampf(0.66 + 0.28 * pulse + 0.24 * sweep_focus, 0.0, 1.0)

	# The scene contains an authored open ring. Rotating/scaling it gives timing
	# feedback without constructing the warning art through draw calls.
	countdown_ring.rotation = (1.0 - progress) * TAU
	countdown_ring.scale = Vector2.ONE * (0.82 + 0.18 * progress)
	countdown_ring.modulate.a = clampf(0.72 + 0.20 * pulse + 0.14 * sweep_focus, 0.0, 1.0)

	sweep_ring.visible = sweep_focus > 0.001
	sweep_ring.scale = Vector2.ONE * (0.92 + 0.22 * sweep_focus)
	sweep_ring.modulate.a = 0.42 * sweep_focus
