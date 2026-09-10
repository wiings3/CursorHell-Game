@tool
extends Node2D

@export_category("Arena")
@export var arena: Rect2 = Rect2()
@export var background_color := Color(0.088, 0.098, 0.118, 1.0)
@export var grid_size: float = 52.0
@export var grid_color := Color(0.62, 0.55, 0.50, 0.065)
@export var inner_edge_color := Color(0.30, 0.28, 0.28, 0.10)
@export var border_color := Color(0.012, 0.010, 0.013, 1.0)
@export var border_width: float = 7.0
@export var corner_color := Color(1.0, 0.60, 0.18, 0.30)
@export var corner_length: float = 24.0
@export var corner_inset: float = 9.0

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func _draw() -> void:
	draw_rect(arena, background_color, true)

	var x := arena.position.x + grid_size
	while x < arena.end.x:
		draw_line(Vector2(x, arena.position.y), Vector2(x, arena.end.y), grid_color, 1.0)
		x += grid_size

	var y := arena.position.y + grid_size
	while y < arena.end.y:
		draw_line(Vector2(arena.position.x, y), Vector2(arena.end.x, y), grid_color, 1.0)
		y += grid_size

	# Slightly brighter inner edge gives incoming-warning markers a clean surface.
	draw_rect(arena.grow(-5.0), inner_edge_color, false, 1.0)
	draw_rect(arena, border_color, false, border_width)

	# Small corner accents visually frame the playable area without adding clutter.
	var tl := arena.position + Vector2(corner_inset, corner_inset)
	var tr := Vector2(arena.end.x - corner_inset, arena.position.y + corner_inset)
	var bl := Vector2(arena.position.x + corner_inset, arena.end.y - corner_inset)
	var br := arena.end - Vector2(corner_inset, corner_inset)

	draw_line(tl, tl + Vector2(corner_length, 0), corner_color, 2.0)
	draw_line(tl, tl + Vector2(0, corner_length), corner_color, 2.0)
	draw_line(tr, tr + Vector2(-corner_length, 0), corner_color, 2.0)
	draw_line(tr, tr + Vector2(0, corner_length), corner_color, 2.0)
	draw_line(bl, bl + Vector2(corner_length, 0), corner_color, 2.0)
	draw_line(bl, bl + Vector2(0, -corner_length), corner_color, 2.0)
	draw_line(br, br + Vector2(-corner_length, 0), corner_color, 2.0)
	draw_line(br, br + Vector2(0, -corner_length), corner_color, 2.0)
