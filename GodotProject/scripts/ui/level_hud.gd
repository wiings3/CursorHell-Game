@tool
extends CanvasLayer
class_name CursorHellLevelHUD

@export_multiline var level_display_text: String = "LEVEL 1\nFIRST CONTACT"

@onready var timer_label: Label = %TimerLabel
@onready var score_label: Label = %ScoreLabel
@onready var level_label: Label = %LevelLabel
@onready var tutorial_label: Label = %TutorialLabel
@onready var combo_label: Label = %ComboLabel
@onready var message_scrim: ColorRect = %MessageScrim
@onready var message_border: ColorRect = %MessageBorder
@onready var message_panel: ColorRect = %MessagePanel
@onready var message_title: Label = %MessageTitle
@onready var message_subtitle: Label = %MessageSubtitle
@onready var message_body: Label = %MessageBody
@onready var hit_flash: ColorRect = %HitFlash
@onready var hit_label: Label = %HitLabel
@onready var graze_popup_label: Label = %GrazePopupLabel
@onready var countdown_label: Label = %CountdownLabel
@onready var countdown_subtitle: Label = %CountdownSubtitle

func _ready() -> void:
	level_label.text = level_display_text

func _process(_delta: float) -> void:
	# Keep the per-level label preview live while editing the HUD/level scene.
	if Engine.is_editor_hint() and level_label != null:
		level_label.text = level_display_text
