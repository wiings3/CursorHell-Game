extends Node2D
class_name CursorHellMicroBullet

const ARENA := Rect2(390.0, 72.0, 820.0, 756.0)

var velocity := Vector2.ZERO
var previous_position := Vector2.ZERO
var radius := 7.0
var age := 0.0
var style := "gunner"

func configure(origin: Vector2, direction: Vector2, speed: float, new_radius: float, new_style: String) -> void:
	position = origin
	previous_position = origin
	velocity = direction.normalized() * speed
	radius = maxf(new_radius, 2.0)
	style = new_style
	age = 0.0
	z_index = 7
	queue_redraw()

func advance(delta: float) -> void:
	previous_position = position
	position += velocity * delta
	age += delta
	queue_redraw()

func is_outside() -> bool:
	return age > 0.25 and not ARENA.grow(110.0).has_point(position)

func _draw() -> void:
	var outer := Color(1.0, 0.30, 0.12, 0.96)
	var core := Color(1.0, 0.92, 0.70, 1.0)
	match style:
		"burst":
			outer = Color(0.94, 0.30, 0.92, 0.96)
			core = Color(1.0, 0.82, 1.0, 1.0)
		"sniper":
			outer = Color(1.0, 0.72, 0.18, 1.0)
			core = Color(1.0, 0.98, 0.84, 1.0)

	var trail_direction := Vector2.LEFT
	if velocity.length_squared() > 0.001:
		trail_direction = -velocity.normalized()
	draw_line(Vector2.ZERO, trail_direction * 18.0, Color(outer.r, outer.g, outer.b, 0.38), maxf(2.0, radius * 0.8), true)
	draw_circle(Vector2.ZERO, radius, outer)
	draw_circle(Vector2.ZERO, maxf(2.0, radius * 0.42), core)
