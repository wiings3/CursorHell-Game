extends Node2D
class_name CursorHellMicroCrosshair

var hot := false
var pulse := 0.0

func _process(delta: float) -> void:
	pulse += delta * 7.0
	queue_redraw()

func set_hot(value: bool) -> void:
	if hot == value:
		return
	hot = value
	queue_redraw()

func _draw() -> void:
	var color := Color(0.38, 0.94, 1.0, 0.96)
	if hot:
		color = Color(1.0, 0.72, 0.24, 1.0)
	var radius := 12.0 + sin(pulse) * 0.8
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, color, 1.6, true)
	draw_circle(Vector2.ZERO, 2.2, color)
	draw_line(Vector2(-20.0, 0.0), Vector2(-8.0, 0.0), color, 1.4, true)
	draw_line(Vector2(8.0, 0.0), Vector2(20.0, 0.0), color, 1.4, true)
	draw_line(Vector2(0.0, -20.0), Vector2(0.0, -8.0), color, 1.4, true)
	draw_line(Vector2(0.0, 8.0), Vector2(0.0, 20.0), color, 1.4, true)
