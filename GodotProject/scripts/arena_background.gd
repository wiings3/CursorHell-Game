extends Node2D

var arena: Rect2 = Rect2()

func _draw() -> void:
	draw_rect(arena, Color(0.088, 0.098, 0.118, 1.0), true)

	var grid := 52.0
	var x := arena.position.x + grid
	while x < arena.end.x:
		draw_line(Vector2(x, arena.position.y), Vector2(x, arena.end.y), Color(0.62, 0.55, 0.50, 0.065), 1.0)
		x += grid

	var y := arena.position.y + grid
	while y < arena.end.y:
		draw_line(Vector2(arena.position.x, y), Vector2(arena.end.x, y), Color(0.62, 0.55, 0.50, 0.065), 1.0)
		y += grid

	# Slightly brighter inner edge gives incoming-warning markers a clean surface.
	draw_rect(arena.grow(-5.0), Color(0.30, 0.28, 0.28, 0.10), false, 1.0)
	draw_rect(arena, Color(0.012, 0.010, 0.013, 1.0), false, 7.0)

	# Small corner accents visually frame the playable area without adding clutter.
	var c := Color(1.0, 0.60, 0.18, 0.30)
	var length := 24.0
	var inset := 9.0
	var tl := arena.position + Vector2(inset, inset)
	var tr := Vector2(arena.end.x - inset, arena.position.y + inset)
	var bl := Vector2(arena.position.x + inset, arena.end.y - inset)
	var br := arena.end - Vector2(inset, inset)

	draw_line(tl, tl + Vector2(length, 0), c, 2.0)
	draw_line(tl, tl + Vector2(0, length), c, 2.0)
	draw_line(tr, tr + Vector2(-length, 0), c, 2.0)
	draw_line(tr, tr + Vector2(0, length), c, 2.0)
	draw_line(bl, bl + Vector2(length, 0), c, 2.0)
	draw_line(bl, bl + Vector2(0, -length), c, 2.0)
	draw_line(br, br + Vector2(-length, 0), c, 2.0)
	draw_line(br, br + Vector2(0, -length), c, 2.0)
