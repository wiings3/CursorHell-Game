extends PointLight2D

@export var min_energy: float = 0.3
@export var max_energy: float = 1.0

@export var min_flicker_time: float = 0.04
@export var max_flicker_time: float = 0.15

var flicker_timer: float = 0.0


func _ready() -> void:
	flicker_timer = randf_range(min_flicker_time, max_flicker_time)


func _process(delta: float) -> void:
	flicker_timer -= delta

	if flicker_timer <= 0.0:
		energy = randf_range(min_energy, max_energy)
		flicker_timer = randf_range(min_flicker_time, max_flicker_time)
