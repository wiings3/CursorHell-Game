extends TextureRect

@export_range(0, 255) var min_alpha: int = 0
@export_range(0, 255) var max_alpha: int = 255

@export var min_flicker_time: float = 0.04
@export var max_flicker_time: float = 0.18

var flicker_timer := 0.0


func _ready() -> void:
	flicker_timer = randf_range(min_flicker_time, max_flicker_time)


func _process(delta: float) -> void:
	flicker_timer -= delta

	if flicker_timer <= 0.0:
		var alpha_255 := randi_range(min_alpha, max_alpha)

		var color := self_modulate
		color.a = float(alpha_255) / 255.0
		self_modulate = color

		flicker_timer = randf_range(min_flicker_time, max_flicker_time)
