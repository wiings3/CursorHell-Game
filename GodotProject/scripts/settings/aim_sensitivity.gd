extends RefCounted
class_name CursorHellAimSensitivity

const SETTINGS_PATH := "user://cursor_hell_settings.cfg"
const CS2_YAW := 0.022
const DEFAULT_PRESET := "CS2"
const DEFAULT_CS2_EQUIVALENT := 1.0
const DEFAULT_DPI := 800
const MIN_CS2_EQUIVALENT := 0.01
const MAX_CS2_EQUIVALENT := 10.0
const MIN_DPI := 100
const MAX_DPI := 32000

# Yaw is degrees of rotation per mouse count at sensitivity 1.0. The presets
# model hip-fire/look sensitivity only. Conversions preserve the same canonical
# CS2-equivalent sensitivity even though Cursor Hell is a 2D aiming game.
const PRESETS := [
	{"id": "CS2", "label": "COUNTER-STRIKE 2", "yaw": 0.022, "slider_min": 0.01, "slider_max": 10.0},
	{"id": "VALORANT", "label": "VALORANT", "yaw": 0.07, "slider_min": 0.003, "slider_max": 3.143},
	{"id": "APEX", "label": "APEX LEGENDS", "yaw": 0.022, "slider_min": 0.01, "slider_max": 10.0},
	{"id": "OVERWATCH_2", "label": "OVERWATCH 2", "yaw": 0.0066, "slider_min": 0.034, "slider_max": 33.334},
	{"id": "CALL_OF_DUTY", "label": "CALL OF DUTY", "yaw": 0.0066, "slider_min": 0.034, "slider_max": 33.334}
]

static func get_presets() -> Array:
	return PRESETS

static func is_valid_preset(preset_id: String) -> bool:
	for raw_preset in PRESETS:
		var preset: Dictionary = raw_preset
		if str(preset.get("id", "")) == preset_id:
			return true
	return false

static func get_preset(preset_id: String) -> Dictionary:
	for raw_preset in PRESETS:
		var preset: Dictionary = raw_preset
		if str(preset.get("id", "")) == preset_id:
			return preset
	var fallback: Dictionary = PRESETS[0]
	return fallback

static func get_yaw(preset_id: String) -> float:
	return float(get_preset(preset_id).get("yaw", CS2_YAW))

static func to_cs2_equivalent(preset_id: String, displayed_sensitivity: float) -> float:
	var yaw: float = get_yaw(preset_id)
	var canonical: float = displayed_sensitivity * yaw / CS2_YAW
	return clampf(canonical, MIN_CS2_EQUIVALENT, MAX_CS2_EQUIVALENT)

static func from_cs2_equivalent(preset_id: String, cs2_equivalent: float) -> float:
	var yaw: float = get_yaw(preset_id)
	return clampf(cs2_equivalent, MIN_CS2_EQUIVALENT, MAX_CS2_EQUIVALENT) * CS2_YAW / yaw

static func logical_motion_gain(cs2_equivalent: float) -> float:
	# There is no exact 3D-camera-to-2D-crosshair conversion. The previous FOV
	# projection made low FPS sensitivities unusably slow. Treat the canonical
	# CS2-equivalent number as the 2D mouse-motion gain instead. This preserves
	# the relative scale between supported games while keeping familiar low-sens
	# values practical for a free-moving 2D crosshair.
	return clampf(cs2_equivalent, MIN_CS2_EQUIVALENT, MAX_CS2_EQUIVALENT)

static func cm_per_360(cs2_equivalent: float, dpi: int) -> float:
	var safe_dpi: int = clampi(dpi, MIN_DPI, MAX_DPI)
	var safe_sensitivity: float = clampf(cs2_equivalent, MIN_CS2_EQUIVALENT, MAX_CS2_EQUIVALENT)
	var counts_per_360: float = 360.0 / (CS2_YAW * safe_sensitivity)
	return counts_per_360 / float(safe_dpi) * 2.54

static func cs2_edpi(cs2_equivalent: float, dpi: int) -> float:
	return clampf(cs2_equivalent, MIN_CS2_EQUIVALENT, MAX_CS2_EQUIVALENT) * float(clampi(dpi, MIN_DPI, MAX_DPI))

static func load_profile() -> Dictionary:
	var preset := DEFAULT_PRESET
	var cs2_equivalent := DEFAULT_CS2_EQUIVALENT
	var dpi := DEFAULT_DPI
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		preset = str(config.get_value("aim", "preset", DEFAULT_PRESET))
		if not is_valid_preset(preset):
			preset = DEFAULT_PRESET
		cs2_equivalent = clampf(float(config.get_value("aim", "cs2_equivalent", DEFAULT_CS2_EQUIVALENT)), MIN_CS2_EQUIVALENT, MAX_CS2_EQUIVALENT)
		dpi = clampi(int(config.get_value("aim", "dpi", DEFAULT_DPI)), MIN_DPI, MAX_DPI)
	return {
		"preset": preset,
		"cs2_equivalent": cs2_equivalent,
		"dpi": dpi
	}
