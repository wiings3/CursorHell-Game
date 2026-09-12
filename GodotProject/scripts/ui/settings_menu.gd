extends CanvasLayer
class_name CursorHellSettingsMenu

signal back_requested

const SETTINGS_PATH := "user://cursor_hell_settings.cfg"

@onready var panel_group: Control = $Root/PanelGroup
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value: Label = %VolumeValue
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var vsync_toggle: CheckButton = %VSyncToggle
@onready var reset_button: Button = %ResetButton
@onready var back_button: Button = %BackButton

var panel_home := Vector2.ZERO
var loading_settings := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	panel_home = panel_group.position

	_load_settings()

	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	vsync_toggle.toggled.connect(_on_vsync_toggled)
	reset_button.pressed.connect(_reset_defaults)
	back_button.pressed.connect(func() -> void: back_requested.emit())

func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
		back_requested.emit()
		get_viewport().set_input_as_handled()

func show_menu() -> void:
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh_display_state()
	_animate_open()
	volume_slider.grab_focus()

func hide_menu() -> void:
	visible = false
	panel_group.position = panel_home
	panel_group.modulate.a = 1.0

func _load_settings() -> void:
	loading_settings = true
	var master_index := AudioServer.get_bus_index("Master")
	var default_volume := 100.0
	if master_index >= 0:
		if AudioServer.is_bus_mute(master_index):
			default_volume = 0.0
		else:
			default_volume = clampf(db_to_linear(AudioServer.get_bus_volume_db(master_index)) * 100.0, 0.0, 100.0)

	var mode := DisplayServer.window_get_mode()
	var default_fullscreen := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	var default_vsync := DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED

	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		volume_slider.value = float(config.get_value("audio", "master_volume", default_volume))
		fullscreen_toggle.button_pressed = bool(config.get_value("display", "fullscreen", default_fullscreen))
		vsync_toggle.button_pressed = bool(config.get_value("display", "vsync", default_vsync))
	else:
		volume_slider.value = default_volume
		fullscreen_toggle.button_pressed = default_fullscreen
		vsync_toggle.button_pressed = default_vsync

	_apply_volume(volume_slider.value)
	_apply_fullscreen(fullscreen_toggle.button_pressed)
	_apply_vsync(vsync_toggle.button_pressed)
	loading_settings = false

func _on_volume_changed(value: float) -> void:
	_apply_volume(value)
	_save_settings()

func _on_fullscreen_toggled(enabled: bool) -> void:
	_apply_fullscreen(enabled)
	_save_settings()

func _on_vsync_toggled(enabled: bool) -> void:
	_apply_vsync(enabled)
	_save_settings()

func _apply_volume(value: float) -> void:
	var master_index := AudioServer.get_bus_index("Master")
	var clamped := clampf(value, 0.0, 100.0)
	volume_value.text = "%d%%" % roundi(clamped)
	if master_index < 0:
		return
	AudioServer.set_bus_mute(master_index, clamped <= 0.0)
	if clamped > 0.0:
		AudioServer.set_bus_volume_db(master_index, linear_to_db(clamped / 100.0))

func _apply_fullscreen(enabled: bool) -> void:
	var target_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != target_mode:
		DisplayServer.window_set_mode(target_mode)

func _apply_vsync(enabled: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)

func _refresh_display_state() -> void:
	loading_settings = true
	var mode := DisplayServer.window_get_mode()
	fullscreen_toggle.button_pressed = mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	vsync_toggle.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	loading_settings = false

func _reset_defaults() -> void:
	loading_settings = true
	volume_slider.value = 100.0
	fullscreen_toggle.button_pressed = false
	vsync_toggle.button_pressed = true
	_apply_volume(100.0)
	_apply_fullscreen(false)
	_apply_vsync(true)
	loading_settings = false
	_save_settings()

func _save_settings() -> void:
	if loading_settings:
		return
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", volume_slider.value)
	config.set_value("display", "fullscreen", fullscreen_toggle.button_pressed)
	config.set_value("display", "vsync", vsync_toggle.button_pressed)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Cursor Hell: could not save settings.")

func _animate_open() -> void:
	panel_group.position = panel_home + Vector2(0.0, 14.0)
	panel_group.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel_group, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel_group, "position", panel_home, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
