extends Node2D
class_name CursorHellCabinetMenuStage

const DESIGN_SIZE := CursorHellMachineShell.DESIGN_SIZE

@onready var machine_shell: CursorHellMachineShell = $GameplayMachineShell

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_apply_viewport_layout)
	_apply_viewport_layout()
	var canvas_layer := get_parent() as CanvasLayer
	if canvas_layer != null and is_instance_valid(machine_shell.crt_canvas):
		machine_shell.crt_canvas.layer = canvas_layer.layer + 1

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
