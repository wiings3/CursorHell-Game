extends Node2D
class_name CursorHellGameplayMachineShell

@onready var timer_readout: Label = %MachineTimerReadout
@onready var score_readout: Label = %MachineScoreReadout
@onready var level_number: Label = %MachineLevelNumber
@onready var level_name: Label = %MachineLevelName
@onready var combo_readout: Label = %MachineComboReadout

var _hud: CursorHellLevelHUD

func _ready() -> void:
	_ignore_control_mouse(self)
	call_deferred("_bind_hud")

func _process(_delta: float) -> void:
	if _hud == null or not is_instance_valid(_hud):
		return
	_sync_readouts()

func _bind_hud() -> void:
	_hud = get_parent().get_node_or_null("LevelHUD") as CursorHellLevelHUD
	if _hud == null:
		push_warning("Cursor Hell: machine shell could not find LevelHUD.")
		return

	_hide_legacy_hud_chrome()
	_sync_level_identity()
	_sync_readouts()

func _hide_legacy_hud_chrome() -> void:
	var node_names := [
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
		"ComboLabel",
	]

	for node_name in node_names:
		var item := _hud.get_node_or_null(node_name) as CanvasItem
		if item != null:
			item.visible = false

func _sync_readouts() -> void:
	if _hud.timer_label != null:
		timer_readout.text = _hud.timer_label.text
	if _hud.score_label != null:
		score_readout.text = _hud.score_label.text
	if _hud.combo_label != null:
		combo_readout.text = _hud.combo_label.text
		combo_readout.visible = not combo_readout.text.strip_edges().is_empty()

func _sync_level_identity() -> void:
	var display_text := _hud.level_display_text.strip_edges()
	var number_text := display_text
	var title_text := ""
	var newline_index := display_text.find("\n")
	if newline_index >= 0:
		number_text = display_text.substr(0, newline_index).strip_edges()
		title_text = display_text.substr(newline_index + 1).strip_edges()

	var boss_separator := title_text.find(" // BOSS")
	if boss_separator >= 0:
		title_text = title_text.substr(0, boss_separator).strip_edges()

	level_number.text = number_text
	level_name.text = title_text

func _ignore_control_mouse(node: Node) -> void:
	var control := node as Control
	if control != null:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for child in node.get_children():
		_ignore_control_mouse(child)
