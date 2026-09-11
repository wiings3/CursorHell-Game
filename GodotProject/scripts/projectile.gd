@tool
extends Node2D
class_name CursorHellProjectile

@export_category("Movement")
@export var velocity: Vector2 = Vector2.ZERO
@export var max_age: float = 10.0

@export_category("Shape")
@export var radius: float = 7.0

@export_category("Colors")
@export var trail_color := Color(1.0, 0.29, 0.05, 1.0)
@export var flare_color := Color(1.0, 0.25, 0.035, 0.96)
@export var glow_color := Color(1.0, 0.35, 0.045, 0.16)
@export var body_color := Color(1.0, 0.50, 0.07, 1.0)
@export var core_color := Color(1.0, 0.88, 0.42, 1.0)
@export var center_color := Color(1.0, 0.99, 0.84, 1.0)

var age: float = 0.0

# All projectile history stays in the projectile layer's LOCAL 1600x900
# coordinate space. Do not convert this back to global_position: the fullscreen
# display scaling bug in v0.3 came from mixing those coordinate systems.
var trail: Array[Vector2] = []
var previous_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	previous_position = position
	queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	age += delta
	if age >= max_age:
		queue_free()
		return

	previous_position = position
	position += velocity * delta

	trail.push_front(position)
	if trail.size() > 10:
		trail.pop_back()

	queue_redraw()

func _draw() -> void:
	var speed := velocity.length()
	var direction := Vector2.RIGHT if speed <= 0.1 else velocity.normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var streak_scale := clampf(speed / 300.0, 0.78, 1.30)

	# Layered trail: a broad ember haze underneath a brighter inner streak. The
	# trail remains entirely visual; projectile history used for collision is unchanged.
	for i in range(trail.size() - 1):
		var a := trail[i] - position
		var b := trail[i + 1] - position
		var normalized_age := float(i) / maxf(1.0, float(trail.size() - 1))
		var fade := 1.0 - normalized_age

		var haze := glow_color
		haze.a = 0.10 * fade
		draw_line(a, b, haze, maxf(2.0, radius * 1.55 * fade), true)

		var streak := trail_color
		streak.a = 0.28 * fade
		draw_line(a, b, streak, maxf(1.0, radius * 0.72 * fade), true)

	# Directional flare scales slightly with speed so faster shots feel sharper
	# without changing their collision radius.
	var back := -direction * (radius * 2.55 * streak_scale)
	var tip := direction * (radius * 1.45)
	var p1 := back + perpendicular * radius * 0.78
	var p2 := back - perpendicular * radius * 0.78
	draw_colored_polygon(PackedVector2Array([tip, p1, p2]), flare_color)

	# Multiple translucent layers produce a compact hot glow while keeping the true
	# danger size readable even during the dense later levels.
	var wide_glow := glow_color
	wide_glow.a *= 0.62
	draw_circle(Vector2.ZERO, radius * 1.55, wide_glow)
	draw_circle(Vector2.ZERO, radius * 1.22, glow_color)

	# The bright body now reaches the actual collision radius. This makes projectile
	# size visually honest, especially for the large slow blockers in THE FLOOD.
	draw_circle(Vector2.ZERO, radius, body_color)

	var collision_edge := core_color
	collision_edge.a = 0.92
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, collision_edge, maxf(1.0, radius * 0.13), true)

	draw_circle(Vector2.ZERO, radius * 0.52, core_color)
	draw_circle(Vector2.ZERO, radius * 0.22, center_color)

	var hot_pin := Color(1.0, 1.0, 1.0, 0.92)
	draw_circle(Vector2.ZERO, maxf(1.0, radius * 0.075), hot_pin)
