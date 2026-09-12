@tool
extends Node2D
class_name CursorHellWarningLayer

const WarningMarkerScene := preload("res://Scenes/Components/WarningMarker.tscn")
const NeedleWarningMarkerScene := preload("res://Scenes/Components/NeedleWarningMarker.tscn")

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
	while runtime_markers.get_child_count() > warnings.size():
		var extra := runtime_markers.get_child(runtime_markers.get_child_count() - 1)
		runtime_markers.remove_child(extra)
		extra.queue_free()

	for index in range(warnings.size()):
		var warning: Dictionary = warnings[index]
		var desired_kind := _warning_kind(warning)
		var marker: CursorHellWarningMarker

		if index >= runtime_markers.get_child_count():
			marker = _create_marker(desired_kind)
			if marker == null:
				return
			runtime_markers.add_child(marker)
		else:
			marker = runtime_markers.get_child(index) as CursorHellWarningMarker
			var current_kind := ""
			if marker != null:
				current_kind = str(marker.get_meta("warning_kind", "standard"))

			if marker == null or current_kind != desired_kind:
				var old_marker := runtime_markers.get_child(index)
				runtime_markers.remove_child(old_marker)
				old_marker.queue_free()
				marker = _create_marker(desired_kind)
				if marker == null:
					return
				runtime_markers.add_child(marker)
				runtime_markers.move_child(marker, index)

		marker.apply_warning(warning, arena)

func _warning_kind(warning: Dictionary) -> String:
	if str(warning.get("warning_kind", "")) == "needle":
		return "needle"
	if str(warning.get("projectile_kind", "")) == "needle":
		return "needle"
	return "standard"

func _create_marker(kind: String) -> CursorHellWarningMarker:
	var marker_scene: PackedScene = NeedleWarningMarkerScene if kind == "needle" else WarningMarkerScene
	var marker := marker_scene.instantiate() as CursorHellWarningMarker
	if marker == null:
		push_error("Cursor Hell: warning marker scene must use CursorHellWarningMarker.")
		return null
	marker.set_meta("warning_kind", kind)
	return marker
