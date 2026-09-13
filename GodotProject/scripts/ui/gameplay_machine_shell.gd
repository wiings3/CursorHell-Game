extends Node2D
class_name CursorHellGameplayMachineShell

@onready var time_readout: Label = %TimeReadout
@onready var score_readout: Label = %ScoreReadout
@onready var combo_readout: Label = %ComboReadout
@onready var physical_level_number: Label = %PhysicalLevelNumber
@onready var physical_level_name: Label = %PhysicalLevelName
@onready var status_text: Label = %StatusText
@onready var status_lamp: ColorRect = %StatusLamp

var _level: CursorHellBaseLevel
var _hud: CursorHellLevelHUD

func _ready() -> void:
	set_process(false)
	call_deferred("_bind_level_ui")

func _bind_level_ui() -> void:
	_level = get_parent() as CursorHellBaseLevel
	if _level == null:
		return

	_hud = _level.get_node_or_null("LevelHUD") as CursorHellLevelHUD
	if _hud == null:
		return

	_hide_legacy_hud_shell()
	_sync_level_plate()
	_sync_readouts()
	set_process(true)

func _process(_delta: float) -> void:
	if not is_instance_valid(_level) or not is_instance_valid(_hud):
		set_process(false)
		return

	_sync_readouts()
	_sync_status()

func _hide_legacy_hud_shell() -> void:
	# Level 1 is the visual-overhaul prototype. Keep all trusted gameplay HUD
	# behavior alive, but hide the old floating instrument shell so its values can
	# be mirrored into the physical cabinet meters instead.
	var legacy_nodes := [
		"TimeTitle",
		"TimerBorder",
		"TimerBox",
		"TimerLabel",
		"TimerAccents",
		"ScoreTitle",
		"ScoreBorder",
		"ScoreBox",
		"ScoreLabel",
		"LevelCard",
		"ComboLabel"
	]

	for node_name in legacy_nodes:
		var node := _hud.get_node_or_null(node_name) as CanvasItem
		if node != null:
			node.visible = false

func _sync_level_plate() -> void:
	physical_level_number.text = "LEVEL %02d" % _level.get_level_number()
	physical_level_name.text = _level.get_level_name()

func _sync_readouts() -> void:
	time_readout.text = _hud.timer_label.text
	score_readout.text = _hud.score_label.text
	combo_readout.text = _hud.combo_label.text
	combo_readout.visible = not combo_readout.text.is_empty()

func _sync_status() -> void:
	match _level.state:
		"intro":
			_set_status("SYSTEM READY", Color(1.0, 0.47, 0.10, 1.0))
		"countdown":
			_set_status("SYNCING", Color(1.0, 0.58, 0.16, 1.0))
		"playing":
			_set_status("RUNNING", Color(1.0, 0.47, 0.10, 1.0))
		"dying", "dead":
			_set_status("FAULT", Color(0.95, 0.12, 0.055, 1.0))
		"won":
			_set_status("TEST COMPLETE", Color(0.35, 0.78, 0.92, 1.0))
		"paused":
			_set_status("SUSPENDED", Color(0.82, 0.58, 0.24, 1.0))
		_:
			_set_status("STANDBY", Color(0.52, 0.36, 0.18, 1.0))

func _set_status(text_value: String, lamp_color: Color) -> void:
	status_text.text = text_value
	status_lamp.color = lamp_color
