extends CanvasLayer
class_name CursorHellMainMenu

signal continue_requested
signal start_level_one_requested
signal quit_requested

@onready var panel_group: Control = $Root/PanelGroup
@onready var ghost_frame: Control = $Root/GhostFrame
@onready var continue_button: Button = %ContinueButton
@onready var start_button: Button = %StartButton
@onready var quit_button: Button = %QuitButton
@onready var save_status: Label = %SaveStatus

var panel_home := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel_home = panel_group.position
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
	_animate_open()
	if not continue_button.disabled:
		continue_button.grab_focus()
	else:
		start_button.grab_focus()

func hide_menu() -> void:
	visible = false
	panel_group.position = panel_home
	panel_group.modulate.a = 1.0
	ghost_frame.modulate.a = 1.0

func _animate_open() -> void:
	panel_group.position = panel_home + Vector2(0.0, 18.0)
	panel_group.modulate.a = 0.0
	ghost_frame.modulate.a = 0.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel_group, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel_group, "position", panel_home, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost_frame, "modulate:a", 1.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
