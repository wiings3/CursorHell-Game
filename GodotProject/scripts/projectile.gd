extends Node2D

var velocity: Vector2 = Vector2.ZERO
var radius: float = 7.0
var age: float = 0.0
var max_age: float = 10.0

# All projectile history stays in the projectile layer's LOCAL 1600x900
# coordinate space. Do not convert this back to global_position: the fullscreen
# display scaling bug in v0.3 came from mixing those coordinate systems.
var trail: Array[Vector2] = []
var previous_position: Vector2 = Vector2.ZERO

func _ready() -> void:
    previous_position = position

func _physics_process(delta: float) -> void:
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

    for i in range(trail.size() - 1):
        var a := trail[i] - position
        var b := trail[i + 1] - position
        var alpha := 0.25 * (1.0 - float(i) / maxf(1.0, float(trail.size())))
        draw_line(a, b, Color(1.0, 0.29, 0.05, alpha), maxf(1.0, radius * 0.9 - i * 0.45))

    # The long flare communicates direction; the bright round core is the danger.
    var back := -direction * (radius * 2.35)
    var tip := direction * (radius * 1.70)
    var p1 := back + perpendicular * radius * 0.82
    var p2 := back - perpendicular * radius * 0.82
    draw_colored_polygon(PackedVector2Array([tip, p1, p2]), Color(1.0, 0.25, 0.035, 0.96))
    draw_circle(Vector2.ZERO, radius * 1.25, Color(1.0, 0.35, 0.045, 0.16))
    draw_circle(Vector2.ZERO, radius * 0.92, Color(1.0, 0.50, 0.07, 1.0))
    draw_circle(Vector2.ZERO, radius * 0.50, Color(1.0, 0.88, 0.42, 1.0))
    draw_circle(Vector2.ZERO, radius * 0.20, Color(1.0, 0.99, 0.84, 1.0))
