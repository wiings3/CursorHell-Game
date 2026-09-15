extends CanvasLayer
class_name CursorHellLeaderboardMenu

signal back_requested
signal callsign_changed(callsign: String)
signal refresh_requested(board: String)

@onready var survival_button: Button = %SurvivalButton
@onready var score_button: Button = %ScoreButton
@onready var callsign_edit: LineEdit = %CallsignEdit
@onready var save_callsign_button: Button = %SaveCallsignButton
@onready var status_label: Label = %StatusLabel
@onready var rows_label: Label = %RowsLabel
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
	rows_label.text = "LOADING GLOBAL RECORDS..."
	refresh_requested.emit(current_board)
	if callsign_edit.text.strip_edges().is_empty():
		callsign_edit.grab_focus()
	else:
		survival_button.grab_focus()

func hide_menu() -> void:
	visible = false

func set_loading() -> void:
	rows_label.text = "LOADING GLOBAL RECORDS..."
	status_label.text = "CONTACTING GLOBAL ARCHIVE..."

func set_error(message: String) -> void:
	status_label.text = message
	rows_label.text = "NO GLOBAL RECORDS AVAILABLE"

func set_status(message: String) -> void:
	status_label.text = message

func set_rows(board: String, rows: Array) -> void:
	current_board = board
	status_label.text = "SURVIVAL RANKING" if board == "survival" else "SCORE RANKING"
	if rows.is_empty():
		rows_label.text = "NO RECORDS YET  //  BE THE FIRST"
		return
	var lines := PackedStringArray()
	lines.append("#    CALLSIGN          TIME       SCORE        PHASE")
	lines.append("------------------------------------------------------")
	for index in range(rows.size()):
		var row = rows[index]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = row
		var name := str(data.get("callsign", "PLAYER")).left(16)
		var time_ms := int(data.get("score_survival_ms", 0)) if board == "score" else int(data.get("best_survival_ms", 0))
		var score := int(data.get("best_score", 0)) if board == "score" else int(data.get("survival_score", 0))
		var phase := int(data.get("score_phase", 0)) if board == "score" else int(data.get("survival_phase", 0))
		var marker := ">" if str(data.get("player_id", "")) == player_id else " "
		lines.append("%s%-3d  %-16s  %-8s  %-11s  %02d" % [marker, index + 1, name, _format_time_ms(time_ms), _format_score(score), phase])
	rows_label.text = "\n".join(lines)

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
