extends CanvasLayer
class_name CursorHellAntiCampTutorial

signal continue_requested

const FLAGS_PATH := "user://cursor_hell_tutorial_flags.cfg"
const FLAGS_SECTION := "tutorials"
const FLAG_KEY := "anti_camp_explained"

@onready var continue_button: Button = %ContinueButton

var _config := ConfigFile.new()
var _already_explained := false
var _tutorial_pending := false
var _was_tree_paused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_flag()
	continue_button.pressed.connect(_on_continue_pressed)
	get_tree().node_added.connect(_on_tree_node_added)
	hide()

func _on_tree_node_added(node: Node) -> void:
	if _already_explained or visible or _tutorial_pending:
		return
	if not (node is CursorHellDisplacementZone):
		return

	# Freeze on the exact frame the first displacement zone enters the tree. The
	# previous deferred popup allowed the warning/gameplay to advance briefly before
	# the pause took effect, which could make the explanation feel unsafe.
	_tutorial_pending = true
	_was_tree_paused = get_tree().paused

	var level := _get_active_level()
	if level != null:
		level.set_process_input(false)

	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	show()
	continue_button.grab_focus()

func _on_continue_pressed() -> void:
	_mark_explained()
	hide()
	_tutorial_pending = false
	continue_requested.emit()

	if not _was_tree_paused:
		get_tree().paused = false

	var level := _get_active_level()
	if level != null and not _was_tree_paused:
		level.set_process_input(true)
		if level.state == "playing" or level.state == "countdown":
			level._capture_mouse()

func debug_reset_explained_flag() -> bool:
	# Developer-only helper used by the debug console so the first-time tutorial
	# can be tested repeatedly without deleting user data by hand.
	_already_explained = false
	_tutorial_pending = false
	_config.set_value(FLAGS_SECTION, FLAG_KEY, false)
	var error := _config.save(FLAGS_PATH)
	if error != OK:
		push_warning("Cursor Hell: could not reset anti-camp tutorial flag.")
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

func _load_flag() -> void:
	var error := _config.load(FLAGS_PATH)
	if error != OK:
		_already_explained = false
		return
	_already_explained = bool(_config.get_value(FLAGS_SECTION, FLAG_KEY, false))

func _mark_explained() -> void:
	if _already_explained:
		return
	_already_explained = true
	_config.set_value(FLAGS_SECTION, FLAG_KEY, true)
	var error := _config.save(FLAGS_PATH)
	if error != OK:
		push_warning("Cursor Hell: could not save anti-camp tutorial flag.")
