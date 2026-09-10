extends CanvasLayer
class_name CursorHellDebugConsole

signal command_submitted(command_line: String)
signal console_opened
signal console_closed

@export var enabled: bool = true

@onready var output: RichTextLabel = %Output
@onready var command_input: LineEdit = %CommandInput

var is_open: bool = false
var command_history: Array[String] = []
var history_index: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	command_input.text_submitted.connect(_on_command_submitted)
	write_line("Cursor Hell debug console. Type 'help' for commands.")

func _input(event: InputEvent) -> void:
	if not enabled or not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if _is_console_key(key_event):
		toggle_console()
		get_viewport().set_input_as_handled()
		return

	if not is_open:
		return

	if key_event.keycode == KEY_ESCAPE:
		close_console()
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_UP:
		_history_previous()
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_DOWN:
		_history_next()
		get_viewport().set_input_as_handled()

func toggle_console() -> void:
	if is_open:
		close_console()
	else:
		open_console()

func open_console() -> void:
	if not enabled or is_open:
		return
	is_open = true
	visible = true
	command_input.grab_focus()
	command_input.caret_column = command_input.text.length()
	console_opened.emit()

func close_console() -> void:
	if not is_open:
		return
	command_input.release_focus()
	visible = false
	is_open = false
	console_closed.emit()

func write_line(text: String) -> void:
	if output == null:
		return
	output.append_text(text + "\n")

func clear_output() -> void:
	if output != null:
		output.clear()

func _on_command_submitted(raw_command: String) -> void:
	var command_line := raw_command.strip_edges()
	command_input.clear()
	if command_line.is_empty():
		return

	if command_history.is_empty() or command_history.back() != command_line:
		command_history.append(command_line)
	history_index = command_history.size()

	write_line("> " + command_line)
	command_submitted.emit(command_line)

func _history_previous() -> void:
	if command_history.is_empty():
		return
	history_index = maxi(0, history_index - 1)
	_set_input_from_history()

func _history_next() -> void:
	if command_history.is_empty():
		return
	history_index = mini(command_history.size(), history_index + 1)
	if history_index >= command_history.size():
		command_input.clear()
		return
	_set_input_from_history()

func _set_input_from_history() -> void:
	command_input.text = command_history[history_index]
	command_input.caret_column = command_input.text.length()

func _is_console_key(event: InputEventKey) -> bool:
	return event.keycode == KEY_QUOTELEFT or event.physical_keycode == KEY_QUOTELEFT
