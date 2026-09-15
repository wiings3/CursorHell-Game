extends CanvasLayer
class_name CursorHellLeaderboardMenu

signal back_requested
signal callsign_changed(callsign: String)
signal refresh_requested(board: String)

const ROW_HEIGHT := 44.0
const NORMAL_TEXT := Color(0.86, 0.85, 0.78, 1)
const OWN_TEXT := Color(1.0, 0.68, 0.28, 1)
const MUTED_TEXT := Color(0.62, 0.65, 0.54, 1)

# Keep minimum widths deliberately conservative. The cells expand by ratio to use
# the available table width, but can never force the cabinet panel wider than its
# authored bounds.
const COLUMN_MIN_WIDTHS := [52.0, 150.0, 92.0, 100.0, 62.0]
const COLUMN_STRETCH := [0.70, 2.60, 1.25, 1.40, 0.90]

@onready var survival_button: Button = %SurvivalButton
@onready var score_button: Button = %ScoreButton
@onready var callsign_edit: LineEdit = %CallsignEdit
@onready var save_callsign_button: Button = %SaveCallsignButton
@onready var status_label: Label = %StatusLabel
@onready var rows_vbox: VBoxContainer = %RowsVBox
@onready var back_button: Button = %BackButton

var current_board := "survival"
var player_id := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	survival_button.pressed.connect(func() -> void: _select_board("survival"))
	score_button.pressed.connect(func() -> void: _select_board("score"))
	save_callsign_button.pressed.connect(_save_callsign)
	callsign_edit.text_submitted.connect(func(_text: String) -> void: _save_callsign())
	back_button.pressed.connect(func() -> void: back_requested.emit())
	hide()

func configure(callsign: String, own_player_id: String) -> void:
	player_id = own_player_id
	callsign_edit.text = callsign
	if callsign.is_empty():
		status_label.text = "CHOOSE A CALLSIGN TO SUBMIT GLOBAL RECORDS"
	else:
		status_label.text = "GLOBAL ENDLESS RECORDS  //  ONLINE"

func show_menu() -> void:
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_show_message_row("LOADING GLOBAL RECORDS...")
	refresh_requested.emit(current_board)
	if callsign_edit.text.strip_edges().is_empty():
		callsign_edit.grab_focus()
	else:
		survival_button.grab_focus()

func hide_menu() -> void:
	visible = false

func set_loading() -> void:
	_show_message_row("LOADING GLOBAL RECORDS...")
	status_label.text = "CONTACTING GLOBAL ARCHIVE..."

func set_error(message: String) -> void:
	status_label.text = message
	_show_message_row("NO GLOBAL RECORDS AVAILABLE")

func set_status(message: String) -> void:
	status_label.text = message

func set_rows(board: String, rows: Array) -> void:
	current_board = board
	status_label.text = "SURVIVAL RANKING" if board == "survival" else "SCORE RANKING"
	_clear_rows()
	if rows.is_empty():
		_add_message_row("NO RECORDS YET  //  BE THE FIRST")
		return

	for index in range(rows.size()):
		var row = rows[index]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = row
		var name := str(data.get("callsign", "PLAYER")).left(16)
		var time_ms := int(data.get("score_survival_ms", 0)) if board == "score" else int(data.get("best_survival_ms", 0))
		var score := int(data.get("best_score", 0)) if board == "score" else int(data.get("survival_score", 0))
		var phase := int(data.get("score_phase", 0)) if board == "score" else int(data.get("survival_phase", 0))
		var is_own := str(data.get("player_id", "")) == player_id
		_add_record_row(index + 1, name, time_ms, score, phase, is_own)

func _select_board(board: String) -> void:
	current_board = board
	set_loading()
	refresh_requested.emit(board)

func _save_callsign() -> void:
	var clean := callsign_edit.text.strip_edges()
	if clean.length() < 1 or clean.length() > 16:
		status_label.text = "CALLSIGN MUST BE 1-16 CHARACTERS"
		return
	var allowed := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 _.-"
	for index in range(clean.length()):
		if allowed.find(clean.substr(index, 1)) < 0:
			status_label.text = "USE LETTERS, NUMBERS, SPACE, _, - OR ."
			return
	callsign_edit.text = clean
	callsign_changed.emit(clean)

func _add_record_row(rank: int, name: String, time_ms: int, score: int, phase: int, is_own: bool) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	rows_vbox.add_child(row)

	var color := OWN_TEXT if is_own else NORMAL_TEXT
	var rank_text := "> %d" % rank if is_own else str(rank)
	row.add_child(_make_cell(rank_text, 0, HORIZONTAL_ALIGNMENT_LEFT, color))
	row.add_child(_make_cell(name, 1, HORIZONTAL_ALIGNMENT_LEFT, color))
	row.add_child(_make_cell(_format_time_ms(time_ms), 2, HORIZONTAL_ALIGNMENT_CENTER, color))
	row.add_child(_make_cell(_format_score(score), 3, HORIZONTAL_ALIGNMENT_CENTER, color))
	row.add_child(_make_cell("%02d" % phase, 4, HORIZONTAL_ALIGNMENT_RIGHT, color))

func _make_cell(text_value: String, column: int, alignment: HorizontalAlignment, color: Color) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(COLUMN_MIN_WIDTHS[column], ROW_HEIGHT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_stretch_ratio = COLUMN_STRETCH[column]
	label.text = text_value
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 16)
	return label

func _show_message_row(message: String) -> void:
	_clear_rows()
	_add_message_row(message)

func _add_message_row(message: String) -> void:
	var label := Label.new()
	label.custom_minimum_size = Vector2(0, 100)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", MUTED_TEXT)
	label.add_theme_font_size_override("font_size", 15)
	rows_vbox.add_child(label)

func _clear_rows() -> void:
	for child in rows_vbox.get_children():
		child.queue_free()

func _format_time_ms(milliseconds: int) -> String:
	var total_seconds := maxf(0.0, float(milliseconds) / 1000.0)
	var whole := int(floor(total_seconds))
	return "%d:%02d.%01d" % [int(whole / 60), whole % 60, int(floor(fmod(total_seconds, 1.0) * 10.0))]

func _format_score(value: int) -> String:
	var text := str(maxi(value, 0))
	var result := ""
	while text.length() > 3:
		result = "," + text.right(3) + result
		text = text.left(text.length() - 3)
	return text + result
