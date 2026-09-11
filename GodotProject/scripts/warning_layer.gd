@tool
extends Node2D
class_name CursorHellWarningLayer

const WarningMarkerScene := preload("res://Scenes/Components/WarningMarker.tscn")

@export var arena: Rect2 = Rect2()
var warnings: Array = []

@onready var runtime_markers: Node2D = $RuntimeMarkers
@onready var design_preview: Node2D = $DesignPreview

func _ready() -> void:
	# Keep one example marker visible in the 2D editor so the warning art can be
	# selected and inspected. It never appears during gameplay.
	if Engine.is_editor_hint():
		design_preview.visible = true
	else:
		design_preview.visible = false

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_sync_warning_markers()

func _sync_warning_markers() -> void:
	while runtime_markers.get_child_count() < warnings.size():
		var marker := WarningMarkerScene.instantiate() as CursorHellWarningMarker
		if marker == null:
			push_error("Cursor Hell: WarningMarker.tscn must use CursorHellWarningMarker.")
			return
		runtime_markers.add_child(marker)

	while runtime_markers.get_child_count() > warnings.size():
		var extra := runtime_markers.get_child(runtime_markers.get_child_count() - 1)
		runtime_markers.remove_child(extra)
		extra.queue_free()

	for index in range(warnings.size()):
		var marker := runtime_markers.get_child(index) as CursorHellWarningMarker
		if marker == null:
			continue
		marker.apply_warning(warnings[index], arena)
