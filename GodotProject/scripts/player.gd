@tool
extends Node2D
class_name CursorHellPlayer

@export_category("Shape")
@export var radius: float = 10.0
@export var visual_radius: float = 13.0

@export_category("Colors")
@export var halo_color := Color(1.0, 0.72, 0.25, 1.0)
@export var outer_glow_color := Color(1.0, 0.95, 0.78, 1.0)
@export var body_color := Color(0.985, 0.975, 0.92, 1.0)
@export var center_color := Color(0.055, 0.050, 0.060, 1.0)
@export var accent_color := Color(1.0, 0.66, 0.20, 1.0)

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
	var halo := halo_color
	halo.a = glow_alpha
	draw_circle(Vector2.ZERO, visual_radius + 8.5, halo)

	var outer_glow := outer_glow_color
	outer_glow.a = 0.15 + danger_flash * 0.16
	draw_circle(Vector2.ZERO, visual_radius + 5.0, outer_glow)

	# Clear cursor-like silhouette.
	draw_circle(Vector2.ZERO, visual_radius, body_color)
	draw_circle(Vector2.ZERO, radius * 0.50, center_color)
	draw_circle(Vector2.ZERO, radius * 0.30, accent_color)
