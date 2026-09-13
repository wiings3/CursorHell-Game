extends Node2D
class_name CursorHellGameplayMachineShell

@onready var timer_readout: Label = %MachineTimerReadout
@onready var score_readout: Label = %MachineScoreReadout
@onready var combo_readout: Label = %MachineComboReadout

var _hud: CursorHellLevelHUD

func _ready() -> void:
	call_deferred("_bind_hud")

func _process(_delta: float) -> void:
	if _hud == null or not is_instance_valid(_hud):
		return
	_sync_readouts()

func _bind_hud() -> void:
	_hud = get_parent().get_node_or_null("LevelHUD") as CursorHellLevelHUD
	if _hud == null:
		push_warning("Cursor Hell: GameplayMachineShell could not find LevelHUD.")
		return

	_hide_legacy_hud_chrome()
	_sync_readouts()

func _hide_legacy_hud_chrome() -> void:
	# Keep the trusted HUD/controller alive, but let the physical machine own the
	# normal gameplay readouts. Tutorial/countdown/impact/message overlays remain.
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
		var raw_score := _hud.score_label.text.strip_edges()
		if raw_score.is_valid_int():
			score_readout.text = "%05d" % int(raw_score)
		else:
			score_readout.text = raw_score

	if _hud.combo_label != null:
		combo_readout.text = _hud.combo_label.text
		combo_readout.visible = not combo_readout.text.strip_edges().is_empty()
