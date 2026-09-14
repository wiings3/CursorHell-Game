extends Node2D
class_name CursorHellWarningMarker

const GUIDE_DASH_LENGTH := 14.0

@onready var guide_back: Line2D = $GuideBack
@onready var guide_glow: Line2D = $GuideGlow
@onready var guide: Line2D = $Guide
@onready var edge_wide: Line2D = $EdgeWide
@onready var edge_core: Line2D = $EdgeCore
@onready var marker_body: Node2D = $MarkerBody
@onready var arrow: Polygon2D = $MarkerBody/Arrow
@onready var countdown_ring: Line2D = $MarkerBody/CountdownRing
@onready var sweep_ring: Line2D = $MarkerBody/SweepRing

var base_edge_wide_width: float = 7.0
var base_edge_core_width: float = 2.0
var countdown_full_points: PackedVector2Array = PackedVector2Array()
var guide_length: float = 820.0
var guide_back_alpha: float = 1.0
var guide_glow_alpha: float = 1.0
var guide_alpha: float = 1.0

func _ready() -> void:
	base_edge_wide_width = edge_wide.width
	base_edge_core_width = edge_core.width
	# The authored Line2D nodes remain the editable style source, but the actual
	# travel path is drawn as dashes so it reads as a telegraph instead of a solid
	# object the player should physically avoid.
	guide_back.visible = false
	guide_glow.visible = false
	guide.visible = false
	# Cache the authored full ring from the marker scene. Runtime only controls
	# timing/visibility; the warning art itself remains editable in the .tscn files.
	countdown_full_points = PackedVector2Array(countdown_ring.points)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(guide_back) or not is_instance_valid(guide_glow) or not is_instance_valid(guide):
		return

	var start := Vector2(-11.0, 0.0)
	var finish := Vector2(guide_length - 11.0, 0.0)
	var back_color := guide_back.default_color
	var glow_color := guide_glow.default_color
	var core_color := guide.default_color
	back_color.a *= guide_back_alpha
	glow_color.a *= guide_glow_alpha
	core_color.a *= guide_alpha

	# All three layers use the same dash cadence so the dark separation, glow and
	# bright core line up cleanly rather than creating visual noise between gaps.
	draw_dashed_line(start, finish, back_color, guide_back.width, GUIDE_DASH_LENGTH, true, true)
	draw_dashed_line(start, finish, glow_color, guide_glow.width, GUIDE_DASH_LENGTH, true, true)
	draw_dashed_line(start, finish, core_color, guide.width, GUIDE_DASH_LENGTH, true, true)

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

	guide_length = arena.size.x
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

	# Keep the same separation/glow/core hierarchy and pulse behavior as the old
	# solid guides; only the path topology changes from continuous to dashed.
	guide_back_alpha = clampf(0.66 + 0.16 * pulse + 0.08 * sweep_focus, 0.0, 1.0)
	guide_glow_alpha = clampf(0.18 + 0.18 * pulse + 0.10 * sweep_focus, 0.0, 0.52)
	guide_alpha = clampf(0.58 + 0.34 * pulse + 0.08 * sweep_focus, 0.0, 1.0)
	queue_redraw()

	edge_wide.width = base_edge_wide_width + 4.0 * sweep_focus
	edge_core.width = base_edge_core_width + sweep_focus
	edge_wide.modulate.a = clampf(0.82 + 0.16 * pulse + 0.12 * sweep_focus, 0.0, 1.0)
	edge_core.modulate.a = clampf(0.90 + 0.10 * sweep_focus, 0.0, 1.0)

	var marker_scale := 1.02 + 0.04 * pulse + 0.28 * sweep_focus
	marker_body.scale = Vector2.ONE * marker_scale
	arrow.modulate.a = clampf(0.82 + 0.16 * pulse + 0.18 * sweep_focus, 0.0, 1.0)

	_update_countdown_ring(progress)
	countdown_ring.modulate.a = clampf(0.82 + 0.16 * pulse + 0.12 * sweep_focus, 0.0, 1.0)

	sweep_ring.visible = sweep_focus > 0.001
	sweep_ring.scale = Vector2.ONE * (0.92 + 0.22 * sweep_focus)
	sweep_ring.modulate.a = 0.48 * sweep_focus

func _update_countdown_ring(progress: float) -> void:
	countdown_ring.rotation = 0.0
	countdown_ring.scale = Vector2.ONE

	var point_count := countdown_full_points.size()
	if point_count < 2 or progress <= 0.001:
		countdown_ring.visible = false
		return

	countdown_ring.visible = true
	var segment_count := point_count
	var visible_segments := clampi(int(ceil(float(segment_count) * progress)), 1, segment_count)

	if visible_segments >= segment_count:
		countdown_ring.points = countdown_full_points
		countdown_ring.closed = true
		return

	var visible_points := PackedVector2Array()
	for index in range(visible_segments + 1):
		visible_points.append(countdown_full_points[index])
	countdown_ring.points = visible_points
	countdown_ring.closed = false
