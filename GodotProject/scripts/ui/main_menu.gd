extends CanvasLayer
class_name CursorHellMainMenu

signal continue_requested
signal start_level_one_requested
signal quit_requested

@onready var continue_button: Button = %ContinueButton
@onready var start_button: Button = %StartButton
@onready var quit_button: Button = %QuitButton
@onready var save_status: Label = %SaveStatus

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	continue_button.pressed.connect(func() -> void: continue_requested.emit())
	start_button.pressed.connect(func() -> void: start_level_one_requested.emit())
	quit_button.pressed.connect(func() -> void: quit_requested.emit())

func configure(has_save: bool, continue_level: int, highest_unlocked: int) -> void:
	continue_button.disabled = not has_save
	if has_save:
		continue_button.text = "CONTINUE  //  LEVEL %d" % continue_level
		save_status.text = "AUTO-SAVE ACTIVE  //  HIGHEST UNLOCKED: LEVEL %d" % highest_unlocked
	else:
		continue_button.text = "CONTINUE  //  NO SAVE"
		save_status.text = "PROGRESS AND BEST SCORES SAVE AUTOMATICALLY"

func show_menu() -> void:
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if not continue_button.disabled:
		continue_button.grab_focus()
	else:
		start_button.grab_focus()

func hide_menu() -> void:
	visible = false
