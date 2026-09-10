extends Node
class_name CursorHellMain

const LEVEL_SCENES: Array[PackedScene] = [
	preload("res://Scenes/Levels/Level1.tscn")
]

@export var starting_level_index: int = 0

@onready var level_container: Node = %LevelContainer

var current_level_index: int = -1
var current_level: CursorHellBaseLevel
var last_completed_level: int = 0
var last_completed_score: int = 0

func _ready() -> void:
	load_level(starting_level_index)

func load_level(index: int) -> void:
	if index < 0 or index >= LEVEL_SCENES.size():
		push_error("Cursor Hell: level index %d is not registered in Main." % index)
		return

	if is_instance_valid(current_level):
		current_level.queue_free()
		current_level = null

	current_level_index = index
	var level_instance := LEVEL_SCENES[index].instantiate()
	level_container.add_child(level_instance)

	current_level = level_instance as CursorHellBaseLevel
	if current_level == null:
		push_error("Cursor Hell: loaded level does not extend CursorHellBaseLevel.")
		return

	current_level.level_completed.connect(_on_level_completed)
	current_level.level_failed.connect(_on_level_failed)

func reload_current_level() -> void:
	if current_level_index >= 0:
		load_level(current_level_index)

func load_next_level() -> bool:
	var next_index := current_level_index + 1
	if next_index >= LEVEL_SCENES.size():
		return false
	load_level(next_index)
	return true

func _on_level_completed(level_number: int, final_score: int) -> void:
	# This is deliberately only a hook for now. The level keeps showing its
	# completion panel until we add an explicit continue/level-select flow.
	last_completed_level = level_number
	last_completed_score = final_score

func _on_level_failed(_level_number: int, _final_score: int) -> void:
	# Failure/retry presentation currently belongs to the level itself.
	pass
