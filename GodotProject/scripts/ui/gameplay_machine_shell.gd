@tool
extends Node2D
class_name CursorHellMachineShell

const CrashTrace = preload("res://scripts/debug/crash_trace.gd")
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
@onready var crt_canvas: CanvasLayer = $CRTCanvas
@onready var crt_overlay: ColorRect = $CRTCanvas/ColorRect

func _ready() -> void:
	if not Engine.is_editor_hint():
		CrashTrace.reset()
		CrashTrace.write("GameplayMachineShell._ready BEGIN")
	# BaseLevel updates its root transform before child components. Keep the CRT
	# on the same transform as this authored cabinet so it cannot drift when the
	# window letterboxes or the cabinet shakes on impact.
	process_priority = 50
	screen.resized.connect(_update_arena_transform)
	_update_arena_transform()
	_sync_crt_canvas()
	set_process(true)
	if not Engine.is_editor_hint():
		CrashTrace.write("GameplayMachineShell._ready END")

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_update_arena_transform()
	_sync_crt_canvas()

func _update_arena_transform() -> void:
	if not is_instance_valid(screen) or not is_instance_valid(arena_content):
		return
	arena_content.scale = screen.size / LOGICAL_ARENA.size
	arena_content.position = -LOGICAL_ARENA.position * arena_content.scale

func _sync_crt_canvas() -> void:
	if not is_instance_valid(crt_canvas) or not is_instance_valid(crt_overlay):
		return
	# CanvasLayer does not inherit a Node2D parent's transform. Explicitly mirror
	# the machine shell, otherwise the CRT can separate from the monitor at any
	# non-1920x1080 viewport or during impact shake.
	crt_canvas.transform = global_transform
	var screen_rect := get_layout_rect(screen)
	if crt_overlay.position != screen_rect.position:
		crt_overlay.position = screen_rect.position
	if crt_overlay.size != screen_rect.size:
		crt_overlay.size = screen_rect.size

func get_layout_rect(area: Control) -> Rect2:
	# Markers under the display sprites follow their authored positions/scales.
	var local_transform := global_transform.affine_inverse() * area.get_global_transform()
	return local_transform * Rect2(Vector2.ZERO, area.size)
