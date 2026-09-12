extends Node
class_name CursorHellMain

const LEVEL_SCENES: Array[PackedScene] = [
	preload("res://Scenes/Levels/Level1.tscn"),
	preload("res://Scenes/Levels/Level2.tscn"),
	preload("res://Scenes/Levels/Level3.tscn"),
	preload("res://Scenes/Levels/Level4.tscn"),
	preload("res://Scenes/Campaign/Boss1.tscn"),
	preload("res://Scenes/Campaign/Level6.tscn"),
	preload("res://Scenes/Campaign/Level7.tscn"),
	preload("res://Scenes/Campaign/Level8.tscn"),
	preload("res://Scenes/Campaign/Level9.tscn")
]

@export var starting_level_index: int = 0
@export var show_main_menu_on_launch: bool = true

@export_category("Debug")
@export var debug_console_enabled: bool = true

@onready var level_container: Node = %LevelContainer
@onready var transition_overlay: CursorHellTransitionOverlay = %TransitionOverlay
@onready var main_menu: CursorHellMainMenu = %MainMenu
@onready var level_select_menu: CursorHellLevelSelectMenu = %LevelSelectMenu
@onready var pause_menu: CursorHellPauseMenu = %PauseMenu
@onready var settings_menu: CursorHellSettingsMenu = %SettingsMenu
@onready var debug_console: CursorHellDebugConsole = %DebugConsole

var save_manager := CursorHellSaveManager.new()
var current_level_index: int = -1
var current_level: CursorHellBaseLevel
var current_level_records_progress := true
var last_completed_level: int = 0
var last_completed_score: int = 0
var settings_return_to_pause := false

func _ready() -> void:
	# Main must keep running while the SceneTree is paused so it can coordinate
	# debug-console state and the dedicated pause/settings overlays.
	process_mode = Node.PROCESS_MODE_ALWAYS

	save_manager.load_save(LEVEL_SCENES.size())

	transition_overlay.primary_requested.connect(_on_transition_primary_requested)
	transition_overlay.replay_requested.connect(_on_transition_replay_requested)
	transition_overlay.menu_requested.connect(_on_transition_menu_requested)

	main_menu.continue_requested.connect(_on_main_menu_continue_requested)
	main_menu.start_level_one_requested.connect(_on_main_menu_start_requested)
	main_menu.level_select_requested.connect(_on_main_menu_level_select_requested)
	main_menu.settings_requested.connect(_on_main_menu_settings_requested)
	main_menu.quit_requested.connect(_quit_game)

	level_select_menu.level_selected.connect(_on_level_selected)
	level_select_menu.back_requested.connect(_on_level_select_back_requested)
	settings_menu.back_requested.connect(_on_settings_back_requested)

	pause_menu.resume_requested.connect(_on_pause_resume_requested)
	pause_menu.restart_requested.connect(_on_pause_restart_requested)
	pause_menu.settings_requested.connect(_on_pause_settings_requested)
	pause_menu.main_menu_requested.connect(_on_pause_main_menu_requested)
	pause_menu.quit_requested.connect(_quit_game)

	debug_console.enabled = debug_console_enabled
	debug_console.command_submitted.connect(_on_debug_command_submitted)
	debug_console.console_opened.connect(_on_debug_console_opened)
	debug_console.console_closed.connect(_on_debug_console_closed)

	if show_main_menu_on_launch:
		_show_main_menu()
	else:
		load_level(starting_level_index, false)

func _process(_delta: float) -> void:
	# BaseLevel's existing Escape behavior changes its local state to "paused".
	# Promote that lightweight state into a real SceneTree pause on the next frame.
	if not is_instance_valid(current_level):
		return
	if main_menu.visible or level_select_menu.visible or pause_menu.visible or settings_menu.visible or debug_console.is_open:
		return
	if current_level.state == "paused":
		_open_pause_menu()

func load_level(index: int, record_progress: bool = true) -> void:
	if index < 0 or index >= LEVEL_SCENES.size():
		push_error("Cursor Hell: level index %d is not registered in Main." % index)
		return

	get_tree().paused = false
	settings_return_to_pause = false
	transition_overlay.hide_immediate()
	main_menu.hide_menu()
	level_select_menu.hide_menu()
	pause_menu.hide_menu()
	settings_menu.hide_menu()

	if is_instance_valid(current_level):
		current_level.queue_free()
		current_level = null

	current_level_index = index
	current_level_records_progress = record_progress
	var level_instance := LEVEL_SCENES[index].instantiate()
	current_level = level_instance as CursorHellBaseLevel
	if current_level == null:
		push_error("Cursor Hell: loaded level does not extend CursorHellBaseLevel.")
		return

	var level_number := index + 1
	current_level.high_score = save_manager.get_best_score(level_number)
	current_level.has_next_level = index < LEVEL_SCENES.size() - 1
	current_level.level_completed.connect(_on_level_completed)
	current_level.level_failed.connect(_on_level_failed)
	current_level.continue_requested.connect(_on_continue_requested)
	level_container.add_child(level_instance)

	# BaseLevel still owns the trusted gameplay/countdown runtime. While a shared
	# transition card is visible, temporarily disable the level's own input and
	# hide its legacy message panel so one click cannot trigger both systems.
	current_level.set_process_input(false)
	current_level._hide_message_panel()
	transition_overlay.show_intro(
		level_number,
		current_level._get_intro_title(),
		current_level._get_intro_subtitle(),
		current_level._get_intro_body()
	)

	if record_progress:
		save_manager.record_level_started(level_number)
		_refresh_main_menu_save_status()

func reload_current_level() -> void:
	if current_level_index >= 0:
		load_level(current_level_index, current_level_records_progress)

func load_next_level() -> bool:
	var next_index := current_level_index + 1
	if next_index >= LEVEL_SCENES.size():
		return false
	load_level(next_index, current_level_records_progress)
	return true

func _on_level_completed(level_number: int, final_score: int) -> void:
	last_completed_level = level_number
	last_completed_score = final_score
	var previous_best := save_manager.get_best_score(level_number)
	var is_new_best := final_score > previous_best

	if current_level_records_progress:
		save_manager.record_level_result(level_number, final_score, true)
		_refresh_main_menu_save_status()

	if not is_instance_valid(current_level):
		return

	current_level._hide_message_panel()
	current_level.set_process_input(false)
	var best_score := maxi(previous_best, final_score)
	transition_overlay.show_clear(
		level_number,
		current_level._get_intro_title(),
		current_level._get_round_time(),
		int(current_level._get_completion_bonus()),
		final_score,
		best_score,
		is_new_best,
		current_level.has_next_level
	)

func _on_level_failed(level_number: int, final_score: int) -> void:
	var previous_best := save_manager.get_best_score(level_number)
	var is_new_best := final_score > previous_best

	if current_level_records_progress:
		save_manager.record_level_result(level_number, final_score, false)
		_refresh_main_menu_save_status()

	if not is_instance_valid(current_level):
		return

	current_level._hide_message_panel()
	current_level.set_process_input(false)
	var best_score := maxi(previous_best, final_score)
	transition_overlay.show_failure(
		level_number,
		current_level._get_intro_title(),
		current_level.pending_death_reason,
		current_level.elapsed,
		current_level._get_round_time(),
		final_score,
		best_score,
		is_new_best
	)

func _on_transition_primary_requested(mode: String) -> void:
	if not is_instance_valid(current_level):
		return

	match mode:
		"intro":
			_begin_current_round()
		"failure":
			_begin_current_round()
		"clear":
			if current_level.has_next_level:
				call_deferred("load_level", current_level_index + 1, current_level_records_progress)
			else:
				_begin_current_round()

func _on_transition_replay_requested(_mode: String) -> void:
	if is_instance_valid(current_level):
		call_deferred("_begin_current_round")

func _on_transition_menu_requested() -> void:
	_show_main_menu()

func _begin_current_round() -> void:
	if not is_instance_valid(current_level):
		return
	transition_overlay.hide_immediate()
	current_level.set_process_input(true)
	current_level._reset_round(true)

func _on_continue_requested() -> void:
	var next_index := current_level_index + 1
	if next_index >= LEVEL_SCENES.size():
		return
	call_deferred("load_level", next_index, current_level_records_progress)

func _show_main_menu() -> void:
	get_tree().paused = false
	settings_return_to_pause = false
	transition_overlay.hide_immediate()
	level_select_menu.hide_menu()
	pause_menu.hide_menu()
	settings_menu.hide_menu()

	if is_instance_valid(current_level):
		current_level.queue_free()
	current_level = null
	current_level_index = -1
	current_level_records_progress = true

	_refresh_main_menu_save_status()
	main_menu.show_menu()

func _refresh_main_menu_save_status() -> void:
	if not is_instance_valid(main_menu):
		return
	main_menu.configure(
		save_manager.has_existing_save,
		save_manager.get_continue_level(),
		save_manager.get_highest_unlocked()
	)

func _on_main_menu_continue_requested() -> void:
	load_level(save_manager.get_continue_level() - 1)

func _on_main_menu_start_requested() -> void:
	# Starting from Level 1 does not erase unlocks or best scores. It simply starts
	# a fresh run from the beginning and updates the saved continuation point.
	load_level(0)

func _on_main_menu_level_select_requested() -> void:
	main_menu.hide_menu()
	var best_scores: Array[int] = []
	for level_number in range(1, LEVEL_SCENES.size() + 1):
		best_scores.append(save_manager.get_best_score(level_number))
	level_select_menu.configure(
		save_manager.get_highest_unlocked(),
		save_manager.get_continue_level(),
		best_scores
	)
	level_select_menu.show_menu()

func _on_level_selected(level_index: int) -> void:
	var level_number := level_index + 1
	if level_index < 0 or level_index >= LEVEL_SCENES.size():
		return
	if level_number > save_manager.get_highest_unlocked():
		return
	level_select_menu.hide_menu()
	load_level(level_index)

func _on_level_select_back_requested() -> void:
	level_select_menu.hide_menu()
	_refresh_main_menu_save_status()
	main_menu.show_menu()

func _on_main_menu_settings_requested() -> void:
	settings_return_to_pause = false
	main_menu.hide_menu()
	settings_menu.show_menu()

func _open_pause_menu() -> void:
	if not is_instance_valid(current_level):
		return
	current_level._hide_message_panel()
	get_tree().paused = true
	pause_menu.show_for_level(current_level_index + 1)

func _on_pause_resume_requested() -> void:
	if not is_instance_valid(current_level):
		_show_main_menu()
		return

	pause_menu.hide_menu()
	get_tree().paused = false
	current_level.set_process_input(true)
	current_level.state = "playing"
	current_level._hide_message_panel()
	current_level._capture_mouse()

func _on_pause_restart_requested() -> void:
	if current_level_index < 0:
		_show_main_menu()
		return

	get_tree().paused = false
	pause_menu.hide_menu()
	load_level(current_level_index, current_level_records_progress)

func _on_pause_settings_requested() -> void:
	if not is_instance_valid(current_level):
		return
	settings_return_to_pause = true
	pause_menu.hide_menu()
	settings_menu.show_menu()

func _on_settings_back_requested() -> void:
	settings_menu.hide_menu()
	if settings_return_to_pause and is_instance_valid(current_level):
		settings_return_to_pause = false
		get_tree().paused = true
		pause_menu.show_for_level(current_level_index + 1)
		return

	settings_return_to_pause = false
	get_tree().paused = false
	_refresh_main_menu_save_status()
	main_menu.show_menu()

func _on_pause_main_menu_requested() -> void:
	_show_main_menu()

func _quit_game() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().quit()

func _on_debug_console_opened() -> void:
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_debug_console_closed() -> void:
	if pause_menu.visible or (settings_menu.visible and settings_return_to_pause):
		get_tree().paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return

	get_tree().paused = false

	if main_menu.visible or level_select_menu.visible or settings_menu.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return

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

	# Debug jumping and any retries/continuations from that debug run must not
	# unlock levels or overwrite the player's real continuation/high scores.
	load_level(index, false)
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
