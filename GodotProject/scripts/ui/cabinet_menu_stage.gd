extends Node2D
class_name CursorHellCabinetMenuStage

const DESIGN_SIZE := CursorHellMachineShell.DESIGN_SIZE
const MenuSideReadoutsScene := preload("res://Scenes/UI/MenuSideReadouts.tscn")

@onready var machine_shell: CursorHellMachineShell = $GameplayMachineShell

var host_canvas: CanvasLayer
var screen_wash: CanvasItem

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	host_canvas = get_parent() as CanvasLayer
	screen_wash = get_node_or_null("ScreenWash") as CanvasItem

	# The gameplay cabinet already owns the intended CRT treatment. Menu scenes
	# must not add another darkening pass on top of it.
	if is_instance_valid(screen_wash):
		screen_wash.visible = false

	# The TIME/SCORE art contains gameplay-looking sample digits. Cover only the
	# value windows while this shell is being used as a menu cabinet so the machine
	# reads as idle. The reusable scene keeps this presentation authored, not drawn
	# procedurally, and gameplay's cabinet/HUD remain untouched.
	if get_node_or_null("MenuSideReadouts") == null:
		var idle_readouts := MenuSideReadoutsScene.instantiate()
		add_child(idle_readouts)

	get_viewport().size_changed.connect(_apply_viewport_layout)
	_apply_viewport_layout()

	# A nested CanvasLayer is independent from its parent's visibility/layer.
	# Put the cabinet CRT immediately above this menu and explicitly synchronize
	# visibility so hidden persistent menus can never stack CRT passes.
	if host_canvas != null and is_instance_valid(machine_shell.crt_canvas):
		machine_shell.crt_canvas.layer = host_canvas.layer + 1
	_sync_crt_visibility()

func _process(_delta: float) -> void:
	_sync_crt_visibility()

func _sync_crt_visibility() -> void:
	if not is_instance_valid(machine_shell) or not is_instance_valid(machine_shell.crt_canvas):
		return
	machine_shell.crt_canvas.visible = host_canvas == null or host_canvas.visible

func _apply_viewport_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var viewport_scale := minf(
		viewport_size.x / DESIGN_SIZE.x,
		viewport_size.y / DESIGN_SIZE.y
	)
	scale = Vector2.ONE * viewport_scale
	position = (viewport_size - DESIGN_SIZE * viewport_scale) * 0.5
