extends CanvasLayer
class_name CursorHellMainMenu

const CrashTrace = preload("res://scripts/debug/crash_trace.gd")

signal continue_requested
signal start_level_one_requested
signal prototype_requested
signal precision_prototype_requested
signal level_select_requested
signal endless_requested
signal leaderboard_requested
signal settings_requested
signal quit_requested

@onready var panel_group: Control = $Root/PanelGroup
@onready var ghost_frame: Control = $Root/GhostFrame
@onready var continue_button: Button = %ContinueButton
@onready var start_button: Button = %StartButton
@onready var prototype_button: Button = %PrototypeButton
@onready var precision_prototype_button: Button = %PrecisionPrototypeButton
@onready var level_select_button: Button = %LevelSelectButton
@onready var endless_button: Button = %EndlessButton
@onready var leaderboard_button: Button = %LeaderboardButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var save_status: Label = %SaveStatus

var panel_home := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel_home = panel_group.position
	continue_button.pressed.connect(_trace_continue_request)
	start_button.pressed.connect(_trace_campaign_request)
	prototype_button.pressed.connect(_trace_prototype_request)
	precision_prototype_button.pressed.connect(_trace_precision_prototype_request)
	level_select_button.pressed.connect(func() -> void: level_select_requested.emit())
	endless_button.pressed.connect(_trace_endless_request)
	leaderboard_button.pressed.connect(func() -> void: leaderboard_requested.emit())
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	quit_button.pressed.connect(func() -> void: quit_requested.emit())

func _trace_continue_request() -> void:
	CrashTrace.reset()
	CrashTrace.write("MAIN MENU: CONTINUE pressed; emitting continue_requested")
	continue_requested.emit()
	CrashTrace.write("MAIN MENU: continue_requested returned")

func _trace_campaign_request() -> void:
	CrashTrace.reset()
	CrashTrace.write("MAIN MENU: START GAME pressed; emitting start_level_one_requested")
	start_level_one_requested.emit()
	CrashTrace.write("MAIN MENU: start_level_one_requested returned")

func _trace_prototype_request() -> void:
	CrashTrace.reset()
	CrashTrace.write("MAIN MENU: ROUTE PROTOTYPE pressed; emitting prototype_requested")
	prototype_requested.emit()
	CrashTrace.write("MAIN MENU: prototype_requested returned")

func _trace_precision_prototype_request() -> void:
	CrashTrace.reset()
	CrashTrace.write("MAIN MENU: PRECISION PROTOTYPE pressed; emitting precision_prototype_requested")
	precision_prototype_requested.emit()
	CrashTrace.write("MAIN MENU: precision_prototype_requested returned")

func _trace_endless_request() -> void:
	CrashTrace.reset()
	CrashTrace.write("MAIN MENU: ENDLESS pressed; emitting endless_requested")
	endless_requested.emit()
	CrashTrace.write("MAIN MENU: endless_requested returned")

func configure(has_save: bool, continue_level: int, highest_unlocked: int, endless_best_time: float = 0.0) -> void:
	continue_button.disabled = not has_save
	if has_save:
		continue_button.text = "CONTINUE  //  LEVEL %d" % continue_level
		save_status.text = "AUTO-SAVE ACTIVE  //  HIGHEST UNLOCKED: LEVEL %d" % highest_unlocked
	else:
		continue_button.text = "CONTINUE  //  NO SAVE"
		save_status.text = "PROGRESS AND BEST SCORES SAVE AUTOMATICALLY"

	if endless_best_time > 0.0:
		endless_button.text = "ENDLESS MODE  //  BEST %s" % _format_time(endless_best_time)
	else:
		endless_button.text = "ENDLESS MODE"

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

func _format_time(seconds: float) -> String:
	var whole := maxi(0, int(floor(seconds)))
	return "%d:%02d" % [int(whole / 60), whole % 60]
