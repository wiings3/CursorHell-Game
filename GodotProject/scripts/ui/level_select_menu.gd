extends CanvasLayer
class_name CursorHellLevelSelectMenu

signal level_selected(level_index: int)
signal back_requested

const LEVEL_NAMES: PackedStringArray = [
	"FIRST CONTACT",
	"CROSSFIRE",
	"THE SWEEP",
	"THE GAP",
	"SYNTHESIS",
	"THE PULSE",
	"THE FLOOD",
	"AFTERSHOCK",
	"DEAD ZONES",
	"CONVERGENCE"
]

const BOSS_TAGS: PackedStringArray = [
	"", "", "", "", "BOSS I",
	"", "", "", "", "BOSS II"
]

const PROGRESS_TRACK_WIDTH := 1030.0

@onready var panel_group: Control = $Root/PanelGroup
@onready var level_buttons: Array[Button] = [
	%Level1Button,
	%Level2Button,
	%Level3Button,
	%Level4Button,
	%Level5Button,
	%Level6Button,
	%Level7Button,
	%Level8Button,
	%Level9Button,
	%Level10Button
]
@onready var back_button: Button = %BackButton
@onready var progress_label: Label = %ProgressLabel
@onready var progress_hint: Label = %ProgressHint
@onready var progress_fill: ColorRect = %ProgressFill

var panel_home := Vector2.ZERO
var preferred_focus_index := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	panel_home = panel_group.position

	for index in range(level_buttons.size()):
		level_buttons[index].pressed.connect(_on_level_pressed.bind(index))
	back_button.pressed.connect(func() -> void: back_requested.emit())

func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
		back_requested.emit()
		get_viewport().set_input_as_handled()

func configure(
	highest_unlocked: int,
	preferred_level: int,
	best_scores: Array[int],
	best_times: Array[float],
	best_ranks: Array[String]
) -> void:
	var safe_highest := clampi(highest_unlocked, 1, level_buttons.size())
	preferred_focus_index = clampi(preferred_level - 1, 0, safe_highest - 1)
	progress_label.text = "%02d / %02d TESTS UNLOCKED" % [safe_highest, level_buttons.size()]
	progress_hint.text = "CONTINUE  //  LEVEL %02d  //  %s" % [
		preferred_focus_index + 1,
		LEVEL_NAMES[preferred_focus_index]
	]
	progress_fill.size.x = PROGRESS_TRACK_WIDTH * (float(safe_highest) / float(level_buttons.size()))

	for index in range(level_buttons.size()):
		var level_number := index + 1
		var button := level_buttons[index]
		var unlocked := level_number <= safe_highest
		var best_score := best_scores[index] if index < best_scores.size() else 0
		var best_time := best_times[index] if index < best_times.size() else 0.0
		var best_rank := best_ranks[index].strip_edges().to_upper() if index < best_ranks.size() else ""
		var boss_tag := BOSS_TAGS[index]
		var title := "LEVEL %02d  //  %s" % [level_number, LEVEL_NAMES[index]]
		if not boss_tag.is_empty():
			title += "  [%s]" % boss_tag

		button.disabled = not unlocked
		if unlocked:
			var rank_text := best_rank if not best_rank.is_empty() else "--"
			var time_text := _format_time(best_time)
			button.text = "%s\nBEST SCORE  %s    LONGEST  %s    RANK  %s" % [
				title,
				_format_score(best_score),
				time_text,
				rank_text
			]
			button.tooltip_text = "Highest score: %s\nLongest survival: %s\nHighest rank: %s" % [
				_format_score(best_score),
				time_text,
				rank_text
			]
		else:
			button.text = "%s\nLOCKED  //  CLEAR THE PREVIOUS TEST TO UNLOCK" % title
			button.tooltip_text = "Locked"

func show_menu() -> void:
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_animate_open()
	if preferred_focus_index >= 0 and preferred_focus_index < level_buttons.size():
		level_buttons[preferred_focus_index].grab_focus()

func hide_menu() -> void:
	visible = false
	panel_group.position = panel_home
	panel_group.modulate.a = 1.0
	panel_group.scale = Vector2.ONE

func _on_level_pressed(index: int) -> void:
	if index < 0 or index >= level_buttons.size() or level_buttons[index].disabled:
		return
	level_selected.emit(index)

func _animate_open() -> void:
	panel_group.position = panel_home + Vector2(0.0, 18.0)
	panel_group.scale = Vector2(0.985, 0.985)
	panel_group.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel_group, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel_group, "position", panel_home, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel_group, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _format_time(value: float) -> String:
	if value <= 0.0:
		return "--:--.-"
	var total_tenths := maxi(0, roundi(value * 10.0))
	var minutes := int(total_tenths / 600)
	var seconds := int(total_tenths / 10) % 60
	var tenths := total_tenths % 10
	return "%d:%02d.%d" % [minutes, seconds, tenths]

func _format_score(value: int) -> String:
	var remaining := str(maxi(value, 0))
	var result := ""
	while remaining.length() > 3:
		result = "," + remaining.substr(remaining.length() - 3, 3) + result
		remaining = remaining.substr(0, remaining.length() - 3)
	return remaining + result
