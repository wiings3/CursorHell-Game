extends Node2D
class_name CursorHellProjectile

@export_category("Movement")
@export var velocity: Vector2 = Vector2.ZERO
@export var max_age: float = 10.0

@export_category("Collision")
@export var radius: float = 7.0

var age: float = 0.0

# Projectile history remains in the projectile layer's LOCAL 1600x900 coordinate
# space. Do not convert this to global_position; collision depends on this history.
var previous_position: Vector2 = Vector2.ZERO

@onready var visual_root: Node2D = $VisualRoot
@onready var directional_root: Node2D = $VisualRoot/DirectionalRoot
@onready var speed_stretch: Node2D = $VisualRoot/DirectionalRoot/SpeedStretch

func _ready() -> void:
	previous_position = position
	_update_scene_visuals()

func _physics_process(delta: float) -> void:
	age += delta
	if age >= max_age:
		queue_free()
		return

	previous_position = position
	position += velocity * delta
	_update_scene_visuals()

func _update_scene_visuals() -> void:
	# Projectile appearance is authored entirely in Projectile.tscn. Runtime code
	# only rotates/scales that authored scene to match direction, speed and radius.
	var radius_scale := maxf(radius, 0.01) / 7.0
	visual_root.scale = Vector2.ONE * radius_scale

	var speed := velocity.length()
	if speed > 0.1:
		directional_root.rotation = velocity.angle()

	# Faster bullets stretch only the directional tail group. Editing the child
	# polygons in the 2D editor still controls the actual look.
	speed_stretch.scale.x = clampf(speed / 300.0, 0.78, 1.30)
