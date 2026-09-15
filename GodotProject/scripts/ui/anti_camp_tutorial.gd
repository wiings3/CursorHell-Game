extends CanvasLayer
class_name CursorHellAntiCampTutorial

signal continue_requested

const FLAGS_PATH := "user://cursor_hell_tutorial_flags.cfg"
const FLAGS_SECTION := "tutorials"
const ANTI_CAMP_FLAG_KEY := "anti_camp_explained"
const SCORE_TARGET_FLAG_KEY := "score_target_explained"

const TUTORIAL_ANTI_CAMP := "anti_camp"
const TUTORIAL_SCORE_TARGET := "score_target"
const CrashTrace = preload("res://scripts/debug/crash_trace.gd")

@onready var eyebrow_label: Label = $Root/PanelGroup/Panel/VBox/Eyebrow
@onready var title_label: Label = $Root/PanelGroup/Panel/VBox/Title
@onready var title_accent: ColorRect = $Root/PanelGroup/Panel/VBox/TitleAccent
@onready var rule_label: Label = $Root/PanelGroup/Panel/VBox/RuleLabel
@onready var body_label: Label = $Root/PanelGroup/Panel/VBox/Body
@onready var continue_button: Button = %ContinueButton

var _config := ConfigFile.new()
var _anti_camp_explained := false
var _score_target_explained := false
var _tutorial_pending := false
var _active_tutorial := ""
var _was_tree_paused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_flags()
	continue_button.pressed.connect(_on_continue_pressed)
	get_tree().node_added.connect(_on_tree_node_added)
	hide()

func _on_tree_node_added(node: Node) -> void:
	if node is CursorHellBaseLevel:
		CrashTrace.write("SceneTree node_added gameplay root: %s" % node.name)
		if not node.ready.is_connected(_on_traced_level_ready.bind(node)):
			node.ready.connect(_on_traced_level_ready.bind(node), CONNECT_ONE_SHOT)

	if visible or _tutorial_pending:
		return

	if node is CursorHellDisplacementZone:
		if _anti_camp_explained:
			return
		_show_tutorial(TUTORIAL_ANTI_CAMP)
		return

	if node is CursorHellScoreTarget:
		if node.get_meta("suppress_score_target_tutorial", false):
			return
		if _score_target_explained:
			return
		_show_tutorial(TUTORIAL_SCORE_TARGET)

func _on_traced_level_ready(level: Node) -> void:
	CrashTrace.write("SceneTree gameplay root READY signal: %s" % level.name)

func _show_tutorial(tutorial_kind: String) -> void:
	_active_tutorial = tutorial_kind
	_tutorial_pending = true
	_was_tree_paused = get_tree().paused
	_apply_tutorial_copy(tutorial_kind)

	# Freeze on the exact frame the mechanic first enters the tree. This keeps the
	# explanation safe and prevents target timers/warnings from advancing behind it.
	var level := _get_active_level()
	if level != null:
		level.set_process_input(false)

	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	show()
	continue_button.grab_focus()

func _apply_tutorial_copy(tutorial_kind: String) -> void:
	if tutorial_kind == TUTORIAL_SCORE_TARGET:
		eyebrow_label.text = "SYSTEM NOTICE  //  TARGET CHAIN PROTOCOL"
		title_label.text = "CHAIN OPPORTUNITY"
		title_accent.color = Color(0.22, 0.92, 1.0, 0.92)
		rule_label.text = "CYAN TARGET = MOVE OVER IT + LEFT CLICK"
		body_label.text = "Score targets are optional opportunities that appear inside the arena.\n\nMOVE YOUR CURSOR OVER THE TARGET and LEFT CLICK it before its timer expires. The cyan ring shows the area that will be purged of live projectiles.\n\nClicking the first target starts a 4-TARGET CHAIN. Each successful hit immediately spawns the next target somewhere else in the arena. Keep moving and clicking before the chain timer runs out.\n\nLater links award more score and clear a larger area. Complete all four for the largest purge and a finisher bonus. Missing a target only ends the chain — there is no penalty."
		return

	eyebrow_label.text = "SYSTEM NOTICE  //  DISPLACEMENT PROTOCOL"
	title_label.text = "RELOCATION REQUIRED"
	title_accent.color = Color(0.72, 0.39, 1.0, 0.92)
	rule_label.text = "PURPLE MARK = VACATE THE AREA"
	body_label.text = "You have remained in one pocket long enough for the system to force a relocation.\n\nThe purple circle locks to the position where it appears. It does not chase you.\n\nMOVE OUT OF THE MARKED AREA before the warning completes.\n\nYou can still hold position when it is safe. Relocate only when displacement pressure appears."

func _on_continue_pressed() -> void:
	_mark_active_tutorial_explained()
	hide()
	_tutorial_pending = false
	_active_tutorial = ""
	continue_requested.emit()

	if not _was_tree_paused:
		get_tree().paused = false

	var level := _get_active_level()
	if level != null and not _was_tree_paused:
		level.set_process_input(true)
		if level.state == "playing" or level.state == "countdown":
			level._capture_mouse()

func debug_reset_explained_flag() -> bool:
	# Preserve the existing debug-console command: this resets only the anti-camp
	# explanation, not every first-time mechanic tutorial.
	_anti_camp_explained = false
	_tutorial_pending = false
	_config.set_value(FLAGS_SECTION, ANTI_CAMP_FLAG_KEY, false)
	var error := _config.save(FLAGS_PATH)
	if error != OK:
		push_warning("Cursor Hell: could not reset anti-camp tutorial flag.")
		return false
	return true

func debug_reset_score_target_flag() -> bool:
	_score_target_explained = false
	_tutorial_pending = false
	_config.set_value(FLAGS_SECTION, SCORE_TARGET_FLAG_KEY, false)
	var error := _config.save(FLAGS_PATH)
	if error != OK:
		push_warning("Cursor Hell: could not reset score-target tutorial flag.")
		return false
	return true

func _get_active_level() -> CursorHellBaseLevel:
	var level_container := get_node_or_null("../LevelContainer")
	if level_container == null:
		return null
	for child in level_container.get_children():
		var level := child as CursorHellBaseLevel
		if level != null and is_instance_valid(level):
			return level
	return null

func _load_flags() -> void:
	var error := _config.load(FLAGS_PATH)
	if error != OK:
		_anti_camp_explained = false
		_score_target_explained = false
		return
	_anti_camp_explained = bool(_config.get_value(FLAGS_SECTION, ANTI_CAMP_FLAG_KEY, false))
	_score_target_explained = bool(_config.get_value(FLAGS_SECTION, SCORE_TARGET_FLAG_KEY, false))

func _mark_active_tutorial_explained() -> void:
	if _active_tutorial == TUTORIAL_SCORE_TARGET:
		if _score_target_explained:
			return
		_score_target_explained = true
		_config.set_value(FLAGS_SECTION, SCORE_TARGET_FLAG_KEY, true)
	elif _active_tutorial == TUTORIAL_ANTI_CAMP:
		if _anti_camp_explained:
			return
		_anti_camp_explained = true
		_config.set_value(FLAGS_SECTION, ANTI_CAMP_FLAG_KEY, true)
	else:
		return

	var error := _config.save(FLAGS_PATH)
	if error != OK:
		push_warning("Cursor Hell: could not save tutorial flag: %s" % _active_tutorial)
