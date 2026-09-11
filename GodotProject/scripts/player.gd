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
	var pulse_wave := 0.5 + 0.5 * sin(pulse)
	var glow_alpha: float = 0.07 + 0.035 * pulse_wave
	if danger_flash > 0.0:
		glow_alpha += danger_flash * 0.30

	# Wide, low-opacity halo gives the cursor presence without obscuring incoming
	# projectiles. Near misses briefly brighten the whole silhouette.
	var halo := halo_color
	halo.a = glow_alpha
	draw_circle(Vector2.ZERO, visual_radius + 10.0 + pulse_wave * 1.5, halo)

	var outer_glow := outer_glow_color
	outer_glow.a = 0.12 + danger_flash * 0.18
	draw_circle(Vector2.ZERO, visual_radius + 5.5, outer_glow)

	# Rotating broken ring makes the player read like a deliberate reticle rather
	# than a placeholder circle. It is decorative only and does not affect hitbox.
	var ring_color := accent_color
	ring_color.a = 0.30 + danger_flash * 0.35
	var ring_radius := visual_radius + 8.0
	var rotation := pulse * 0.20
	for quarter in range(4):
		var start_angle := rotation + float(quarter) * PI * 0.5 + 0.14
		var end_angle := start_angle + 0.48
		draw_arc(Vector2.ZERO, ring_radius, start_angle, end_angle, 12, ring_color, 1.35, true)

	# Small cardinal ticks reinforce the cursor/target language while staying clear
	# of the actual collision circle.
	var tick_color := body_color
	tick_color.a = 0.58
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var from := direction * (visual_radius + 3.5)
		var to := direction * (visual_radius + 6.5)
		draw_line(from, to, tick_color, 1.25, true)

	# Solid cursor body.
	draw_circle(Vector2.ZERO, visual_radius, body_color)

	# Explicitly show the true damaging radius. The art extends slightly beyond it,
	# but this thin ring tells the player exactly what must avoid projectiles.
	var hitbox_ring := accent_color
	hitbox_ring.a = 0.72 + danger_flash * 0.28
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, hitbox_ring, 1.35, true)

	draw_circle(Vector2.ZERO, radius * 0.50, center_color)
	draw_circle(Vector2.ZERO, radius * 0.29, accent_color)

	var pin_color := body_color
	pin_color.a = 0.95
	draw_circle(Vector2.ZERO, radius * 0.10, pin_color)
