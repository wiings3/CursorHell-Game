extends Node
class_name CursorHellMain

const LEVEL_SCENES: Array[PackedScene] = [
	preload("res://Scenes/Levels/Level1.tscn"),
	preload("res://Scenes/Levels/Level2.tscn"),
	preload("res://Scenes/Levels/Level3.tscn"),
	preload("res://Scenes/Levels/Level4.tscn"),
	preload("res://Scenes/Levels/Level5.tscn"),
	preload("res://Scenes/Levels/Level6.tscn"),
	preload("res://Scenes/Levels/Level7.tscn")
]

@export var starting_level_index: int = 0

@export_category("Debug")
@export var debug_console_enabled: bool = true

@onready var level_container: Node = %LevelContainer
@onready var debug_console: CursorHellDebugConsole = %DebugConsole

var current_level_index: int = -1
var current_level: CursorHellBaseLevel
var last_completed_level: int = 0
var last_completed_score: int = 0

func _ready() -> void:
	debug_console.enabled = debug_console_enabled
	debug_console.command_submitted.connect(_on_debug_command_submitted)
	debug_console.console_opened.connect(_on_debug_console_opened)
	debug_console.console_closed.connect(_on_debug_console_closed)
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

	current_level.has_next_level = index < LEVEL_SCENES.size() - 1
	current_level.level_completed.connect(_on_level_completed)
	current_level.level_failed.connect(_on_level_failed)
	current_level.continue_requested.connect(_on_continue_requested)

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
	last_completed_level = level_number
	last_completed_score = final_score

func _on_level_failed(_level_number: int, _final_score: int) -> void:
	# Failure/retry presentation currently belongs to the level itself.
	pass

func _on_continue_requested() -> void:
	var next_index := current_level_index + 1
	if next_index >= LEVEL_SCENES.size():
		return

	# Defer the swap so the click used to continue cannot also trigger the intro
	# screen of the newly loaded level in the same input event.
	call_deferred("load_level", next_index)

func _on_debug_console_opened() -> void:
	# Freeze the entire level while the console is open. The console itself uses
	# PROCESS_MODE_ALWAYS, so it remains interactive while the SceneTree is paused.
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_debug_console_closed() -> void:
	get_tree().paused = false

	# If the player opened the console mid-run, restore captured mouse control.
	# Intro/death/win screens deliberately keep the OS cursor visible.
	if is_instance_valid(current_level) and (current_level.state == "playing" or current_level.state == "countdown"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_debug_command_submitted(command_line: String) -> void:
	var normalized := command_line.strip_edges().to_lower()
	if normalized.is_empty():
		return

	var parts := normalized.split(" ", false)
	var command := parts[0]

	# Convenience syntax: level2, level3, level4... automatically maps to the
	# registered LEVEL_SCENES array, so future levels need no new console command.
	if command.begins_with("level") and command.length() > 5:
		var level_suffix := command.substr(5)
		if level_suffix.is_valid_int():
			_debug_load_level(int(level_suffix))
			return

	match command:
		"level":
			if parts.size() < 2 or not parts[1].is_valid_int():
				debug_console.write_line("Usage: level <number>  (example: level 2)")
				return
			_debug_load_level(int(parts[1]))
		"restart":
			if current_level_index < 0:
				debug_console.write_line("No level is currently loaded.")
				return
			reload_current_level()
			debug_console.write_line("Reloaded level%d." % (current_level_index + 1))
			debug_console.close_console()
		"current":
			if current_level_index >= 0:
				debug_console.write_line("Current level: level%d" % (current_level_index + 1))
			else:
				debug_console.write_line("No level is currently loaded.")
		"levels":
			var registered := PackedStringArray()
			for index in range(LEVEL_SCENES.size()):
				registered.append("level%d" % (index + 1))
			debug_console.write_line("Registered levels: " + ", ".join(registered))
		"clear":
			debug_console.clear_output()
		"close", "exit":
			debug_console.close_console()
		"help":
			_print_debug_help()
		_:
			debug_console.write_line("Unknown command: %s  (type 'help')" % command)

func _debug_load_level(level_number: int) -> void:
	var index := level_number - 1
	if index < 0 or index >= LEVEL_SCENES.size():
		debug_console.write_line("level%d is not registered. Type 'levels' to see available levels." % level_number)
		return

	load_level(index)
	debug_console.write_line("Loaded level%d." % level_number)
	debug_console.close_console()

func _print_debug_help() -> void:
	debug_console.write_line("Commands:")
	debug_console.write_line("  level2 / level 2   Jump directly to a registered level")
	debug_console.write_line("  levels             List registered levels")
	debug_console.write_line("  current            Show the current level")
	debug_console.write_line("  restart            Reload the current level")
	debug_console.write_line("  clear              Clear console output")
	debug_console.write_line("  close              Close the console")
