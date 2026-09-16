extends CanvasLayer
class_name CursorHellSettingsMenu

signal back_requested

const SETTINGS_PATH := "user://cursor_hell_settings.cfg"
const AimSensitivity = preload("res://scripts/settings/aim_sensitivity.gd")

@onready var panel_group: Control = $Root/PanelGroup
@onready var sensitivity_preset: OptionButton = %SensitivityPreset
@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var sensitivity_value: LineEdit = %SensitivityValue
@onready var dpi_value: LineEdit = %DPIValue
@onready var sensitivity_readout: Label = %SensitivityReadout
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value: Label = %VolumeValue
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var vsync_toggle: CheckButton = %VSyncToggle
@onready var reset_button: Button = %ResetButton
@onready var back_button: Button = %BackButton

var panel_home := Vector2.ZERO
var loading_settings := false
var aim_preset := AimSensitivity.DEFAULT_PRESET
var aim_cs2_equivalent := AimSensitivity.DEFAULT_CS2_EQUIVALENT
var aim_dpi := AimSensitivity.DEFAULT_DPI

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	panel_home = panel_group.position

	_populate_sensitivity_presets()
	_load_settings()

	sensitivity_preset.item_selected.connect(_on_sensitivity_preset_selected)
	sensitivity_slider.value_changed.connect(_on_sensitivity_slider_changed)
	sensitivity_value.text_submitted.connect(_on_sensitivity_text_submitted)
	sensitivity_value.focus_exited.connect(_commit_sensitivity_text)
	dpi_value.text_submitted.connect(_on_dpi_text_submitted)
	dpi_value.focus_exited.connect(_commit_dpi_text)
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
	sensitivity_preset.grab_focus()

func hide_menu() -> void:
	_commit_sensitivity_text()
	_commit_dpi_text()
	visible = false
	panel_group.position = panel_home
	panel_group.modulate.a = 1.0

func _populate_sensitivity_presets() -> void:
	sensitivity_preset.clear()
	for raw_preset in AimSensitivity.get_presets():
		var preset: Dictionary = raw_preset
		var index := sensitivity_preset.item_count
		sensitivity_preset.add_item(str(preset.get("label", preset.get("id", "FPS"))))
		sensitivity_preset.set_item_metadata(index, str(preset.get("id", AimSensitivity.DEFAULT_PRESET)))

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
		aim_preset = str(config.get_value("aim", "preset", AimSensitivity.DEFAULT_PRESET))
		if not AimSensitivity.is_valid_preset(aim_preset):
			aim_preset = AimSensitivity.DEFAULT_PRESET
		aim_cs2_equivalent = clampf(
			float(config.get_value("aim", "cs2_equivalent", AimSensitivity.DEFAULT_CS2_EQUIVALENT)),
			AimSensitivity.MIN_CS2_EQUIVALENT,
			AimSensitivity.MAX_CS2_EQUIVALENT
		)
		aim_dpi = clampi(
			int(config.get_value("aim", "dpi", AimSensitivity.DEFAULT_DPI)),
			AimSensitivity.MIN_DPI,
			AimSensitivity.MAX_DPI
		)
	else:
		volume_slider.value = default_volume
		fullscreen_toggle.button_pressed = default_fullscreen
		vsync_toggle.button_pressed = default_vsync
		aim_preset = AimSensitivity.DEFAULT_PRESET
		aim_cs2_equivalent = AimSensitivity.DEFAULT_CS2_EQUIVALENT
		aim_dpi = AimSensitivity.DEFAULT_DPI

	_select_preset_by_id(aim_preset)
	_sync_aim_controls()
	_apply_volume(volume_slider.value)
	_apply_fullscreen(fullscreen_toggle.button_pressed)
	_apply_vsync(vsync_toggle.button_pressed)
	loading_settings = false

func _select_preset_by_id(preset_id: String) -> void:
	for index in range(sensitivity_preset.item_count):
		if str(sensitivity_preset.get_item_metadata(index)) == preset_id:
			sensitivity_preset.select(index)
			return
	sensitivity_preset.select(0)

func _sync_aim_controls() -> void:
	var preset: Dictionary = AimSensitivity.get_preset(aim_preset)
	sensitivity_slider.min_value = float(preset.get("slider_min", 0.01))
	sensitivity_slider.max_value = float(preset.get("slider_max", 10.0))
	sensitivity_slider.step = 0.001
	var displayed := AimSensitivity.from_cs2_equivalent(aim_preset, aim_cs2_equivalent)
	sensitivity_slider.value = clampf(displayed, sensitivity_slider.min_value, sensitivity_slider.max_value)
	sensitivity_value.text = _format_sensitivity(displayed)
	dpi_value.text = str(aim_dpi)
	_refresh_aim_readout()

func _refresh_aim_readout() -> void:
	var cm360 := AimSensitivity.cm_per_360(aim_cs2_equivalent, aim_dpi)
	var edpi := AimSensitivity.cs2_edpi(aim_cs2_equivalent, aim_dpi)
	sensitivity_readout.text = "FPS REFERENCE  //  %.2f CM/360  //  CS2 EDPI %.0f" % [cm360, edpi]

func _format_sensitivity(value: float) -> String:
	var text := String.num(value, 3)
	while text.contains(".") and text.ends_with("0"):
		text = text.left(text.length() - 1)
	if text.ends_with("."):
		text = text.left(text.length() - 1)
	return text

func _on_sensitivity_preset_selected(index: int) -> void:
	if loading_settings or index < 0 or index >= sensitivity_preset.item_count:
		return
	aim_preset = str(sensitivity_preset.get_item_metadata(index))
	loading_settings = true
	_sync_aim_controls()
	loading_settings = false
	_save_settings()

func _on_sensitivity_slider_changed(value: float) -> void:
	if loading_settings:
		return
	aim_cs2_equivalent = AimSensitivity.to_cs2_equivalent(aim_preset, value)
	sensitivity_value.text = _format_sensitivity(AimSensitivity.from_cs2_equivalent(aim_preset, aim_cs2_equivalent))
	_refresh_aim_readout()
	_save_settings()

func _on_sensitivity_text_submitted(_text: String) -> void:
	_commit_sensitivity_text()
	sensitivity_preset.grab_focus()

func _commit_sensitivity_text() -> void:
	if loading_settings or not is_instance_valid(sensitivity_value):
		return
	var raw := sensitivity_value.text.strip_edges()
	if raw.is_valid_float():
		aim_cs2_equivalent = AimSensitivity.to_cs2_equivalent(aim_preset, float(raw))
	loading_settings = true
	_sync_aim_controls()
	loading_settings = false
	_save_settings()

func _on_dpi_text_submitted(_text: String) -> void:
	_commit_dpi_text()
	sensitivity_preset.grab_focus()

func _commit_dpi_text() -> void:
	if loading_settings or not is_instance_valid(dpi_value):
		return
	var raw := dpi_value.text.strip_edges()
	if raw.is_valid_int():
		aim_dpi = clampi(int(raw), AimSensitivity.MIN_DPI, AimSensitivity.MAX_DPI)
	dpi_value.text = str(aim_dpi)
	_refresh_aim_readout()
	_save_settings()

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
	aim_preset = AimSensitivity.DEFAULT_PRESET
	aim_cs2_equivalent = AimSensitivity.DEFAULT_CS2_EQUIVALENT
	aim_dpi = AimSensitivity.DEFAULT_DPI
	_select_preset_by_id(aim_preset)
	_sync_aim_controls()
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
	config.set_value("aim", "preset", aim_preset)
	config.set_value("aim", "cs2_equivalent", aim_cs2_equivalent)
	config.set_value("aim", "dpi", aim_dpi)
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
