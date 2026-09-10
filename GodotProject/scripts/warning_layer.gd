@tool
extends Node2D
class_name CursorHellWarningLayer

@export var arena: Rect2 = Rect2()
var warnings: Array = []

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	for warning in warnings:
		var side: int = int(warning.get("side", 0))
		var lane: float = float(warning.get("lane", 0.5))
		var time_left: float = float(warning.get("time", 0.0))
		var duration: float = maxf(0.001, float(warning.get("max", 1.0)))
		var progress: float = clampf(time_left / duration, 0.0, 1.0)
		var pulse: float = 0.45 + 0.55 * absf(sin((1.0 - progress) * PI * 7.0))

		# Level-authored sweep warnings can opt into a stronger sequential focus.
		# Every marker brightens when it reaches the same amount of time before
		# release. Because sweep shots have staggered release times, that focus
		# naturally travels along the edge in the same direction as the attack.
		var sweep_focus := 0.0
		var is_sweep_warning: bool = bool(warning.get("sweep_visual", false))
		if is_sweep_warning:
			var focus_time: float = float(warning.get("sweep_focus_time", 0.55))
			var focus_width: float = maxf(0.05, float(warning.get("sweep_focus_width", 0.18)))
			sweep_focus = clampf(1.0 - absf(time_left - focus_time) / focus_width, 0.0, 1.0)
			if bool(warning.get("sweep_start", false)):
				sweep_focus = clampf(sweep_focus * 1.18, 0.0, 1.0)

		var alpha: float = clampf(0.66 + 0.28 * pulse + 0.24 * sweep_focus, 0.0, 1.0)
		var guide_alpha: float = 0.07 + 0.08 * pulse + 0.13 * sweep_focus
		var pos := Vector2.ZERO
		var angle := 0.0
		var edge_a := Vector2.ZERO
		var edge_b := Vector2.ZERO

		match side:
			0:
				pos = Vector2(arena.position.x + 11.0, arena.position.y + arena.size.y * lane)
				angle = 0.0
				edge_a = Vector2(arena.position.x, pos.y - 18.0)
				edge_b = Vector2(arena.position.x, pos.y + 18.0)
				draw_dashed_line(Vector2(arena.position.x, pos.y), Vector2(arena.end.x, pos.y), Color(1.0, 0.69, 0.18, guide_alpha), 2.0, 11.0)
			1:
				pos = Vector2(arena.end.x - 11.0, arena.position.y + arena.size.y * lane)
				angle = PI
				edge_a = Vector2(arena.end.x, pos.y - 18.0)
				edge_b = Vector2(arena.end.x, pos.y + 18.0)
				draw_dashed_line(Vector2(arena.position.x, pos.y), Vector2(arena.end.x, pos.y), Color(1.0, 0.69, 0.18, guide_alpha), 2.0, 11.0)
			2:
				pos = Vector2(arena.position.x + arena.size.x * lane, arena.position.y + 11.0)
				angle = PI / 2.0
				edge_a = Vector2(pos.x - 18.0, arena.position.y)
				edge_b = Vector2(pos.x + 18.0, arena.position.y)
				draw_dashed_line(Vector2(pos.x, arena.position.y), Vector2(pos.x, arena.end.y), Color(1.0, 0.69, 0.18, guide_alpha), 2.0, 11.0)
			_:
				pos = Vector2(arena.position.x + arena.size.x * lane, arena.end.y - 11.0)
				angle = -PI / 2.0
				edge_a = Vector2(pos.x - 18.0, arena.end.y)
				edge_b = Vector2(pos.x + 18.0, arena.end.y)
				draw_dashed_line(Vector2(pos.x, arena.position.y), Vector2(pos.x, arena.end.y), Color(1.0, 0.69, 0.18, guide_alpha), 2.0, 11.0)

		var edge_width: float = 7.0 + 4.0 * sweep_focus
		draw_line(edge_a, edge_b, Color(1.0, 0.50, 0.08, clampf(0.72 + 0.25 * pulse + 0.18 * sweep_focus, 0.0, 1.0)), edge_width)
		draw_line(edge_a, edge_b, Color(1.0, 0.91, 0.58, clampf(0.72 + 0.24 * sweep_focus, 0.0, 1.0)), 2.0 + sweep_focus)

		var marker_scale: float = 1.0 + 0.28 * sweep_focus
		var dir := Vector2.from_angle(angle)
		var perp := Vector2(-dir.y, dir.x)
		var tip := pos + dir * (22.0 * marker_scale)
		var back := pos - dir * (5.0 * marker_scale)
		draw_colored_polygon(PackedVector2Array([
			tip,
			back + perp * (12.0 * marker_scale),
			back - perp * (12.0 * marker_scale)
		]), Color(1.0, 0.63, 0.12, alpha))

		var arc_radius: float = 22.0 + 3.0 * sweep_focus
		var arc_end: float = -PI / 2.0 + TAU * progress
		draw_arc(pos, arc_radius, -PI / 2.0, arc_end, 28, Color(1.0, 0.91, 0.58, clampf(0.82 + 0.14 * sweep_focus, 0.0, 1.0)), 2.5 + 0.8 * sweep_focus)

		# A short-lived outer ring gives the eye a clean "current beat" without
		# changing the warning shape used by Levels 1 and 2.
		if sweep_focus > 0.0:
			draw_arc(pos, 29.0 + 5.0 * sweep_focus, 0.0, TAU, 30, Color(1.0, 0.78, 0.30, 0.42 * sweep_focus), 2.0)
