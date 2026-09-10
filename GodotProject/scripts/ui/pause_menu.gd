extends CanvasLayer
class_name CursorHellPauseMenu

signal resume_requested
signal restart_requested
signal main_menu_requested
signal quit_requested

@onready var level_label: Label = %LevelLabel
@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var quit_button: Button = %QuitButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	main_menu_button.pressed.connect(func() -> void: main_menu_requested.emit())
	quit_button.pressed.connect(func() -> void: quit_requested.emit())

func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
		resume_requested.emit()
		get_viewport().set_input_as_handled()

func show_for_level(level_number: int) -> void:
	level_label.text = "LEVEL %d" % level_number
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	resume_button.grab_focus()

func hide_menu() -> void:
	visible = false
