extends CanvasLayer
class_name CursorHellLevelSelectMenu

signal level_selected(level_index: int)
signal back_requested

const LevelCatalog = preload("res://scripts/level_catalog.gd")

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
@onready var progress_track: Control = $Root/PanelGroup/Panel/VBox/ProgressTrack
@onready var progress_fill: ColorRect = %ProgressFill
@onready var detail_status: Label = %DetailStatus
@onready var detail_level: Label = %DetailLevel
@onready var detail_name: Label = %DetailName
@onready var detail_boss_tag: Label = %DetailBossTag
@onready var detail_score: Label = %DetailScore
@onready var detail_time: Label = %DetailTime
@onready var detail_rank: Label = %DetailRank
@onready var detail_hint: Label = %DetailHint

var panel_home := Vector2.ZERO
var preferred_focus_index := 0
var highest_unlocked_level := 1
var cached_best_scores: Array[int] = []
var cached_best_times: Array[float] = []
var cached_best_ranks: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	panel_home = panel_group.position

	if level_buttons.size() != LevelCatalog.count():
		push_warning("Cursor Hell: Level Select button count does not match LevelCatalog.")

	for index in range(level_buttons.size()):
		var button := level_buttons[index]
		button.pressed.connect(_on_level_pressed.bind(index))
		button.focus_entered.connect(_show_level_details.bind(index))
		button.mouse_entered.connect(_show_level_details.bind(index))
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
	var available_count := mini(level_buttons.size(), LevelCatalog.count())
	highest_unlocked_level = clampi(highest_unlocked, 1, available_count)
	preferred_focus_index = clampi(preferred_level - 1, 0, highest_unlocked_level - 1)
	cached_best_scores = best_scores.duplicate()
	cached_best_times = best_times.duplicate()
	cached_best_ranks = best_ranks.duplicate()

	var preferred_metadata := LevelCatalog.get_level(preferred_focus_index)
	progress_label.text = "%02d / %02d LEVELS UNLOCKED" % [highest_unlocked_level, available_count]
	progress_hint.text = "CONTINUE  //  %02d %s" % [
		int(preferred_metadata.get("number", preferred_focus_index + 1)),
		str(preferred_metadata.get("name", "UNKNOWN"))
	]
	call_deferred("_sync_progress_fill", available_count)

	for index in range(level_buttons.size()):
		var button := level_buttons[index]
		if index >= LevelCatalog.count():
			button.disabled = true
			button.text = "%02d  UNREGISTERED" % (index + 1)
			button.tooltip_text = "No LevelCatalog entry"
			continue

		var metadata := LevelCatalog.get_level(index)
		var level_number := int(metadata.get("number", index + 1))
		var level_name := str(metadata.get("name", "UNKNOWN"))
		var boss_tag := str(metadata.get("boss_tag", "")).strip_edges()
		var unlocked := level_number <= highest_unlocked_level
		var title := "%02d  %s" % [level_number, level_name]
		if not boss_tag.is_empty():
			title += "  [%s]" % boss_tag

		button.disabled = not unlocked
		button.text = title if unlocked else title + "  //  LOCKED"
		button.tooltip_text = "Open level record" if unlocked else "Clear the previous level to unlock"

	_show_level_details(preferred_focus_index)

func show_menu() -> void:
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_animate_open()
	_show_level_details(preferred_focus_index)
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

func _show_level_details(index: int) -> void:
	if index < 0 or index >= LevelCatalog.count():
		return

	var metadata := LevelCatalog.get_level(index)
	var level_number := int(metadata.get("number", index + 1))
	var level_name := str(metadata.get("name", "UNKNOWN"))
	var boss_tag := str(metadata.get("boss_tag", "")).strip_edges()
	var unlocked := level_number <= highest_unlocked_level
	var best_score := cached_best_scores[index] if index < cached_best_scores.size() else 0
	var best_time := cached_best_times[index] if index < cached_best_times.size() else 0.0
	var best_rank := cached_best_ranks[index].strip_edges().to_upper() if index < cached_best_ranks.size() else ""

	detail_level.text = "LEVEL %02d" % level_number
	detail_name.text = level_name
	detail_boss_tag.visible = not boss_tag.is_empty()
	detail_boss_tag.text = boss_tag

	if unlocked:
		detail_status.text = "AVAILABLE"
		detail_status.add_theme_color_override("font_color", Color(1.0, 0.62, 0.20, 1.0))
		detail_score.text = "BEST SCORE    %s" % _format_score(best_score)
		detail_time.text = "LONGEST       %s" % _format_time(best_time)
		detail_rank.text = "BEST RANK     %s" % (best_rank if not best_rank.is_empty() else "--")
		detail_hint.text = "ENTER / CLICK TO BEGIN"
	else:
		detail_status.text = "ACCESS LOCKED"
		detail_status.add_theme_color_override("font_color", Color(0.68, 0.68, 0.58, 0.78))
		detail_score.text = "BEST SCORE    --"
		detail_time.text = "LONGEST       --:--.-"
		detail_rank.text = "BEST RANK     --"
		detail_hint.text = "CLEAR LEVEL %02d TO UNLOCK" % maxi(1, level_number - 1)

func _sync_progress_fill(available_count: int) -> void:
	if available_count <= 0 or not is_instance_valid(progress_track) or not is_instance_valid(progress_fill):
		return
	progress_fill.size.x = progress_track.size.x * (float(highest_unlocked_level) / float(available_count))

func _animate_open() -> void:
	panel_group.position = panel_home + Vector2(0.0, 12.0)
	panel_group.scale = Vector2(0.99, 0.99)
	panel_group.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel_group, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel_group, "position", panel_home, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel_group, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
