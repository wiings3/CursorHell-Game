@tool
extends CanvasLayer
class_name CursorHellLevelHUD

@export_multiline var level_display_text: String = "LEVEL 1\nFIRST CONTACT"

# These are layout constants rather than exported properties so they can never
# deserialize as null while the @tool script is reloading in the editor.
const INTRO_BODY_BOTTOM := 274.0
const STANDARD_BODY_BOTTOM := 403.14

@onready var timer_label: Label = %TimerLabel
@onready var score_label: Label = %ScoreLabel
@onready var level_number_label: Label = %LevelNumberLabel
@onready var level_name_label: Label = %LevelNameLabel
@onready var boss_tag_label: Label = %BossTagLabel
@onready var tutorial_label: Label = %TutorialLabel
@onready var combo_label: Label = %ComboLabel
@onready var message_scrim: ColorRect = %MessageScrim
@onready var message_border: ColorRect = %MessageBorder
@onready var message_panel: ColorRect = %MessagePanel
@onready var message_title: Label = %MessageTitle
@onready var message_subtitle: Label = %MessageSubtitle
@onready var message_body: Label = %MessageBody
@onready var message_prompt: Label = %MessagePrompt
@onready var hit_flash: ColorRect = %HitFlash
@onready var hit_label: Label = %HitLabel
@onready var graze_popup_label: Label = %GrazePopupLabel
@onready var countdown_label: Label = %CountdownLabel
@onready var countdown_subtitle: Label = %CountdownSubtitle

func _ready() -> void:
	_apply_level_display_text()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		# Keep the per-level label and intro layout preview live while editing.
		_apply_level_display_text()
		if message_body != null:
			message_body.offset_bottom = INTRO_BODY_BOTTOM
		if message_prompt != null:
			message_prompt.visible = true
		return

	_sync_message_prompt()

func _apply_level_display_text() -> void:
	if level_number_label == null or level_name_label == null or boss_tag_label == null:
		return

	var number_text := level_display_text.strip_edges()
	var title_text := ""
	var newline_index := level_display_text.find("\n")
	if newline_index >= 0:
		number_text = level_display_text.substr(0, newline_index).strip_edges()
		title_text = level_display_text.substr(newline_index + 1).strip_edges()

	var boss_text := ""
	var boss_separator := title_text.find(" // BOSS")
	if boss_separator >= 0:
		boss_text = title_text.substr(boss_separator + 4).strip_edges()
		title_text = title_text.substr(0, boss_separator).strip_edges()

	level_number_label.text = number_text
	level_name_label.text = title_text
	boss_tag_label.text = boss_text
	boss_tag_label.visible = not boss_text.is_empty()

func _sync_message_prompt() -> void:
	if message_body == null or message_prompt == null:
		return

	var level := get_parent()
	if level == null:
		return

	var level_state := str(level.get("state"))
	var is_intro := level_state == "intro"
	message_prompt.visible = is_intro

	if is_intro:
		message_body.offset_bottom = INTRO_BODY_BOTTOM
		message_prompt.text = "CLICK TO BEGIN"
		_strip_intro_prompt_from_body()
	else:
		# Death, pause, and completion panels still use their existing body layout.
		message_body.offset_bottom = STANDARD_BODY_BOTTOM

func _strip_intro_prompt_from_body() -> void:
	const INTRO_PROMPT_SUFFIX := "\n\nCLICK TO BEGIN"
	if not message_body.text.ends_with(INTRO_PROMPT_SUFFIX):
		return
	message_body.text = message_body.text.substr(0, message_body.text.length() - INTRO_PROMPT_SUFFIX.length())
