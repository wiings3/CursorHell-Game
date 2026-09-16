extends "res://scripts/modes/precision_prototype.gd"
class_name CursorHellMicrocombatAimPrototype

const AimSensitivity = preload("res://scripts/settings/aim_sensitivity.gd")

var aim_preset := AimSensitivity.DEFAULT_PRESET
var aim_cs2_equivalent := AimSensitivity.DEFAULT_CS2_EQUIVALENT
var aim_dpi := AimSensitivity.DEFAULT_DPI
var aim_motion_gain := AimSensitivity.logical_motion_gain(AimSensitivity.DEFAULT_CS2_EQUIVALENT)

func _ready() -> void:
	_load_aim_profile()
	super._ready()

func _capture_mouse() -> void:
	# Reload here as well so changing aim settings from the pause menu takes effect
	# immediately when the player resumes the room.
	_load_aim_profile()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if (state == "playing" or state == "countdown") and event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_apply_relative_aim(motion.screen_relative)
		return
	super._input(event)

func _update_crosshair_from_mouse() -> void:
	# The parent prototype used absolute OS cursor position. This runtime replaces
	# that path with captured relative motion so FPS-style sensitivity is meaningful.
	pass

func _apply_relative_aim(raw_motion: Vector2) -> void:
	if not is_instance_valid(crosshair):
		return
	var next_position: Vector2 = crosshair.position + raw_motion * aim_motion_gain
	next_position.x = clampf(next_position.x, ARENA.position.x + 8.0, ARENA.end.x - 8.0)
	next_position.y = clampf(next_position.y, ARENA.position.y + 8.0, ARENA.end.y - 8.0)
	crosshair.position = next_position
	_update_crosshair_hot()
	_update_aim_line()

func _load_aim_profile() -> void:
	var profile: Dictionary = AimSensitivity.load_profile()
	aim_preset = str(profile.get("preset", AimSensitivity.DEFAULT_PRESET))
	aim_cs2_equivalent = float(profile.get("cs2_equivalent", AimSensitivity.DEFAULT_CS2_EQUIVALENT))
	aim_dpi = int(profile.get("dpi", AimSensitivity.DEFAULT_DPI))
	aim_motion_gain = AimSensitivity.logical_motion_gain(aim_cs2_equivalent)

func _update_level_tutorial() -> void:
	if not is_instance_valid(tutorial_label):
		return
	if state == "playing":
		var displayed := AimSensitivity.from_cs2_equivalent(aim_preset, aim_cs2_equivalent)
		tutorial_label.text = "WASD MOVE  //  %s %.3f @ %d DPI  //  LMB FIRE" % [aim_preset.replace("_", " "), displayed, aim_dpi]
	else:
		tutorial_label.text = "MOVE THE BODY. AIM INDEPENDENTLY."
