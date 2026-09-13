@tool
extends Node2D
class_name CursorHellMachineShell

const DESIGN_SIZE := Vector2(1920.0, 1080.0)
# Keep the campaign simulation in its existing coordinates. Only its display
# transform changes, so every warning, projectile, pylon and collision agrees.
const LOGICAL_ARENA := Rect2(390.0, 72.0, 820.0, 756.0)

@onready var screen: Control = $ScreenClip
@onready var arena_content: Node2D = $ScreenClip/ArenaContent
@onready var timer_area: Control = $DecayTimer/TimerValueArea
@onready var score_area: Control = $DecayScore/ScoreValueArea
@onready var identity_area: Control = $LevelIdentityArea
@onready var tutorial_area: Control = $TutorialArea
@onready var hint_area: Control = $HintArea

func _ready() -> void:
	screen.resized.connect(_update_arena_transform)
	_update_arena_transform()
	set_process(Engine.is_editor_hint())

func _process(_delta: float) -> void:
	_update_arena_transform()

func _update_arena_transform() -> void:
	if not is_instance_valid(screen) or not is_instance_valid(arena_content):
		return
	arena_content.scale = screen.size / LOGICAL_ARENA.size
	arena_content.position = -LOGICAL_ARENA.position * arena_content.scale

func get_layout_rect(area: Control) -> Rect2:
	# Markers under the display sprites follow their authored positions/scales.
	var local_transform := global_transform.affine_inverse() * area.get_global_transform()
	return local_transform * Rect2(Vector2.ZERO, area.size)
