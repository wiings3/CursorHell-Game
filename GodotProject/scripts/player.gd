extends Node2D

var radius: float = 10.0
var visual_radius: float = 13.0
var pulse: float = 0.0
var danger_flash: float = 0.0

func _process(delta: float) -> void:
    pulse += delta * 4.0
    danger_flash = maxf(0.0, danger_flash - delta * 4.0)
    queue_redraw()

func flash_near_miss() -> void:
    danger_flash = 1.0

func _draw() -> void:
    var glow_alpha: float = 0.08 + 0.035 * sin(pulse)
    if danger_flash > 0.0:
        glow_alpha += danger_flash * 0.28

    # Soft halo: decorative only. The damaging radius remains the small center area.
    draw_circle(Vector2.ZERO, visual_radius + 15.0, Color(1.0, 0.72, 0.25, glow_alpha))
    draw_circle(Vector2.ZERO, visual_radius + 5.0, Color(1.0, 0.95, 0.78, 0.15 + danger_flash * 0.16))

    # Clear cursor-like silhouette.
    draw_circle(Vector2.ZERO, visual_radius, Color(0.985, 0.975, 0.92, 1.0))
    draw_circle(Vector2.ZERO, radius * 0.50, Color(0.055, 0.050, 0.060, 1.0))
    draw_circle(Vector2.ZERO, radius * 0.30, Color(1.0, 0.66, 0.20, 1.0))

    # Four small ticks make the PC read like an intentional reticle, not a loose orb.
    var tick_color := Color(1.0, 0.78, 0.36, 0.72 + danger_flash * 0.22)
    var inner := visual_radius + 5.0
    var outer := visual_radius + 10.0
    draw_line(Vector2(inner, 0), Vector2(outer, 0), tick_color, 2.0)
    draw_line(Vector2(-inner, 0), Vector2(-outer, 0), tick_color, 2.0)
    draw_line(Vector2(0, inner), Vector2(0, outer), tick_color, 2.0)
    draw_line(Vector2(0, -inner), Vector2(0, -outer), tick_color, 2.0)
