extends CanvasLayer
class_name CursorHellTransitionOverlay

signal primary_requested(mode: String)
signal replay_requested(mode: String)
signal menu_requested

const DESIGN_SIZE := Vector2(1600.0, 900.0)

@onready var root: Control = $Root
@onready var scrim: ColorRect = $Root/Scrim
@onready var mode_tint: ColorRect = $Root/ModeTint
@onready var panel_root: Control = $Root/PanelRoot
@onready var panel_border: ColorRect = $Root/PanelRoot/PanelBorder
@onready var accent_bar: ColorRect = $Root/PanelRoot/Panel/AccentBar
@onready var state_label: Label = $Root/PanelRoot/Panel/StateLabel
@onready var title_label: Label = $Root/PanelRoot/Panel/TitleLabel
@onready var subtitle_label: Label = $Root/PanelRoot/Panel/SubtitleLabel
@onready var body_label: Label = $Root/PanelRoot/Panel/BodyLabel
@onready var score_label: Label = $Root/PanelRoot/Panel/ScoreLabel
@onready var best_label: Label = $Root/PanelRoot/Panel/BestLabel
@onready var record_label: Label = $Root/PanelRoot/Panel/RecordLabel
@onready var prompt_label: Label = $Root/PanelRoot/Panel/PromptLabel

var mode := ""
var locked := false
var panel_home := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel_home = panel_root.position
	get_viewport().size_changed.connect(_apply_viewport_layout)
	_apply_viewport_layout()
	hide_immediate()

func _input(event: InputEvent) -> void:
	if not visible or locked:
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_activate_primary()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return

		if key_event.keycode == KEY_ESCAPE:
			menu_requested.emit()
			get_viewport().set_input_as_handled()
			return

		if key_event.physical_keycode == KEY_R:
			if mode == "intro":
				_activate_primary()
			else:
				replay_requested.emit(mode)
			get_viewport().set_input_as_handled()

func show_intro(level_number: int, title: String, subtitle: String, body: String) -> void:
	mode = "intro"
	_set_mode_style(Color(0.38, 0.54, 0.82, 1.0), Color(0.08, 0.12, 0.20, 0.10))
	state_label.text = "LEVEL %d" % level_number
	title_label.text = title
	subtitle_label.text = subtitle
	body_label.offset_bottom = 408.0
	body_label.text = _clean_intro_body(body)
	score_label.visible = false
	best_label.visible = false
	record_label.visible = false
	prompt_label.text = "CLICK OR R TO BEGIN    •    ESC = MENU"
	_show_animated()

func show_failure(level_number: int, title: String, reason: String, run_time: float, round_time: float, final_score: int, best_score: int, is_new_best: bool) -> void:
	mode = "failure"
	_set_mode_style(Color(1.0, 0.24, 0.12, 1.0), Color(0.28, 0.025, 0.018, 0.13))
	state_label.text = "LEVEL FAILED"
	title_label.text = title
	subtitle_label.text = "LEVEL %d  •  IMPACT" % level_number
	body_label.offset_bottom = 312.0
	body_label.text = "%s\nTIME  %s / %s" % [reason.to_upper(), _format_time(run_time), _format_time(round_time)]
	score_label.visible = true
	best_label.visible = true
	record_label.visible = is_new_best
	score_label.text = "SCORE    %s" % _format_score(final_score)
	best_label.text = "BEST     %s" % _format_score(best_score)
	record_label.text = "NEW BEST"
	prompt_label.text = "CLICK OR R TO RETRY    •    ESC = MENU"
	_show_animated()

func show_clear(level_number: int, title: String, round_time: float, completion_bonus: int, final_score: int, best_score: int, is_new_best: bool, has_next_level: bool) -> void:
	mode = "clear"
	_set_mode_style(Color(1.0, 0.62, 0.18, 1.0), Color(0.20, 0.11, 0.025, 0.10))
	state_label.text = "LEVEL CLEAR"
	title_label.text = title
	subtitle_label.text = "LEVEL %d  •  SURVIVED" % level_number
	body_label.offset_bottom = 312.0
	body_label.text = "%s SURVIVED\nCOMPLETION BONUS  +%s" % [_format_time(round_time), _format_score(completion_bonus)]
	score_label.visible = true
	best_label.visible = true
	record_label.visible = is_new_best
	score_label.text = "FINAL    %s" % _format_score(final_score)
	best_label.text = "BEST     %s" % _format_score(best_score)
	record_label.text = "NEW BEST"
	if has_next_level:
		prompt_label.text = "CLICK = CONTINUE    •    R = REPLAY    •    ESC = MENU"
	else:
		prompt_label.text = "CLICK OR R = PLAY AGAIN    •    ESC = MENU"
	_show_animated()

func hide_immediate() -> void:
	visible = false
	locked = false
	mode = ""
	root.modulate.a = 1.0
	panel_root.modulate.a = 1.0
	panel_root.position = panel_home
	panel_root.scale = Vector2.ONE

func _activate_primary() -> void:
	if mode == "intro":
		_dismiss_intro()
	else:
		primary_requested.emit(mode)

func _dismiss_intro() -> void:
	if locked:
		return
	locked = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "modulate:a", 0.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(panel_root, "position", panel_home - Vector2(0.0, 10.0), 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(_on_intro_dismissed)

func _on_intro_dismissed() -> void:
	visible = false
	locked = false
	root.modulate.a = 1.0
	panel_root.position = panel_home
	panel_root.scale = Vector2.ONE
	var finished_mode := mode
	mode = ""
	primary_requested.emit(finished_mode)

func _show_animated() -> void:
	visible = true
	locked = true
	root.modulate.a = 0.0
	panel_root.modulate.a = 0.0
	panel_root.position = panel_home + Vector2(0.0, 18.0)
	panel_root.scale = Vector2(0.97, 0.97)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel_root, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel_root, "position", panel_home, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel_root, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_unlock)

func _unlock() -> void:
	locked = false

func _set_mode_style(accent: Color, tint: Color) -> void:
	panel_border.color = Color(accent.r, accent.g, accent.b, 0.72)
	accent_bar.color = accent
	state_label.add_theme_color_override("font_color", accent)
	record_label.add_theme_color_override("font_color", accent)
	mode_tint.color = tint

func _apply_viewport_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var viewport_scale: float = minf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	var viewport_offset: Vector2 = (viewport_size - DESIGN_SIZE * viewport_scale) * 0.5
	transform = Transform2D(0.0, Vector2.ONE * viewport_scale, 0.0, viewport_offset)

func _clean_intro_body(body: String) -> String:
	var cleaned := body.replace("\n\nCLICK TO BEGIN", "")
	cleaned = cleaned.replace("CLICK TO BEGIN", "")
	return cleaned.strip_edges()

func _format_time(seconds: float) -> String:
	var whole := int(floor(seconds))
	return "%d:%02d" % [int(whole / 60), whole % 60]

func _format_score(value: int) -> String:
	var remaining := str(maxi(value, 0))
	var result := ""
	while remaining.length() > 3:
		result = "," + remaining.substr(remaining.length() - 3, 3) + result
		remaining = remaining.substr(0, remaining.length() - 3)
	return remaining + result
