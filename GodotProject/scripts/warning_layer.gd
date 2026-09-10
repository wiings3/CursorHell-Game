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
        var alpha: float = 0.66 + 0.28 * pulse
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
                draw_dashed_line(Vector2(arena.position.x, pos.y), Vector2(arena.end.x, pos.y), Color(1.0, 0.69, 0.18, 0.07 + 0.08 * pulse), 2.0, 11.0)
            1:
                pos = Vector2(arena.end.x - 11.0, arena.position.y + arena.size.y * lane)
                angle = PI
                edge_a = Vector2(arena.end.x, pos.y - 18.0)
                edge_b = Vector2(arena.end.x, pos.y + 18.0)
                draw_dashed_line(Vector2(arena.position.x, pos.y), Vector2(arena.end.x, pos.y), Color(1.0, 0.69, 0.18, 0.07 + 0.08 * pulse), 2.0, 11.0)
            2:
                pos = Vector2(arena.position.x + arena.size.x * lane, arena.position.y + 11.0)
                angle = PI / 2.0
                edge_a = Vector2(pos.x - 18.0, arena.position.y)
                edge_b = Vector2(pos.x + 18.0, arena.position.y)
                draw_dashed_line(Vector2(pos.x, arena.position.y), Vector2(pos.x, arena.end.y), Color(1.0, 0.69, 0.18, 0.07 + 0.08 * pulse), 2.0, 11.0)
            _:
                pos = Vector2(arena.position.x + arena.size.x * lane, arena.end.y - 11.0)
                angle = -PI / 2.0
                edge_a = Vector2(pos.x - 18.0, arena.end.y)
                edge_b = Vector2(pos.x + 18.0, arena.end.y)
                draw_dashed_line(Vector2(pos.x, arena.position.y), Vector2(pos.x, arena.end.y), Color(1.0, 0.69, 0.18, 0.07 + 0.08 * pulse), 2.0, 11.0)

        draw_line(edge_a, edge_b, Color(1.0, 0.50, 0.08, 0.72 + 0.25 * pulse), 7.0)
        draw_line(edge_a, edge_b, Color(1.0, 0.91, 0.58, 0.72), 2.0)

        var dir := Vector2.from_angle(angle)
        var perp := Vector2(-dir.y, dir.x)
        var tip := pos + dir * 22.0
        var back := pos - dir * 5.0
        draw_colored_polygon(PackedVector2Array([
            tip,
            back + perp * 12.0,
            back - perp * 12.0
        ]), Color(1.0, 0.63, 0.12, alpha))

        var arc_radius: float = 22.0
        var arc_end: float = -PI / 2.0 + TAU * progress
        draw_arc(pos, arc_radius, -PI / 2.0, arc_end, 28, Color(1.0, 0.91, 0.58, 0.82), 2.5)
