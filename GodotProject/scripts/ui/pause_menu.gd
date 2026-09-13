extends CanvasLayer
class_name CursorHellPauseMenu

signal resume_requested
signal restart_requested
signal settings_requested
signal main_menu_requested
signal quit_requested

@onready var scrim: ColorRect = $Root/Scrim
@onready var panel_group: Control = $Root/PanelGroup
@onready var level_label: Label = %LevelLabel
@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var settings_button: Button = %SettingsButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var quit_button: Button = %QuitButton

var panel_home := Vector2.ZERO
var machine_shell: CursorHellMachineShell

func bind_machine_shell(shell: CursorHellMachineShell) -> void:
	machine_shell = shell
	_apply_viewport_layout()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	panel_home = panel_group.position
	get_viewport().size_changed.connect(_apply_viewport_layout)
	_apply_viewport_layout()
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	main_menu_button.pressed.connect(func() -> void: main_menu_requested.emit())
	quit_button.pressed.connect(func() -> void: quit_requested.emit())

func _apply_viewport_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var design_size := CursorHellMachineShell.DESIGN_SIZE
	var viewport_scale := minf(viewport_size.x / design_size.x, viewport_size.y / design_size.y)
	var viewport_offset := (viewport_size - design_size * viewport_scale) * 0.5
	transform = Transform2D(0.0, Vector2.ONE * viewport_scale, 0.0, viewport_offset)
	var root: Control = $Root
	if is_instance_valid(machine_shell):
		var screen_rect := machine_shell.get_layout_rect(machine_shell.screen)
		root.position = screen_rect.position
		root.size = screen_rect.size
	panel_home = (root.size - panel_group.size * panel_group.scale) * 0.5
	panel_group.position = panel_home

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
	_animate_open()
	resume_button.grab_focus()

func hide_menu() -> void:
	visible = false
	scrim.modulate.a = 1.0
	panel_group.modulate.a = 1.0
	panel_group.position = panel_home

func _animate_open() -> void:
	scrim.modulate.a = 0.0
	panel_group.modulate.a = 0.0
	panel_group.position = panel_home + Vector2(0.0, 14.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(scrim, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel_group, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel_group, "position", panel_home, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
