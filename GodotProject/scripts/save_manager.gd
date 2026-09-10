extends RefCounted
class_name CursorHellSaveManager

const SAVE_PATH := "user://cursor_hell_save.json"
const SAVE_VERSION := 1

var data: Dictionary = {}
var has_existing_save := false
var level_count := 1

func load_save(registered_level_count: int) -> void:
	level_count = maxi(registered_level_count, 1)
	data = _default_data()
	has_existing_save = false

	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Cursor Hell: save file exists but could not be opened.")
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Cursor Hell: save data was invalid. Starting with defaults.")
		return

	var loaded: Dictionary = parsed
	data["version"] = SAVE_VERSION
	data["highest_unlocked"] = clampi(int(loaded.get("highest_unlocked", 1)), 1, level_count)
	data["last_level"] = clampi(int(loaded.get("last_level", 1)), 1, int(data["highest_unlocked"]))

	var loaded_scores = loaded.get("best_scores", {})
	if typeof(loaded_scores) == TYPE_DICTIONARY:
		data["best_scores"] = loaded_scores.duplicate(true)
	else:
		data["best_scores"] = {}

	has_existing_save = true

func record_level_started(level_number: int) -> void:
	var safe_level := clampi(level_number, 1, level_count)
	var highest := int(data.get("highest_unlocked", 1))
	data["last_level"] = mini(safe_level, highest)
	has_existing_save = true
	_write_save()

func record_level_result(level_number: int, final_score: int, completed: bool) -> void:
	var safe_level := clampi(level_number, 1, level_count)
	_record_best_score(safe_level, final_score)

	if completed:
		var next_level := mini(safe_level + 1, level_count)
		data["highest_unlocked"] = maxi(int(data.get("highest_unlocked", 1)), next_level)
		data["last_level"] = next_level
	else:
		data["last_level"] = safe_level

	has_existing_save = true
	_write_save()

func get_continue_level() -> int:
	var highest := clampi(int(data.get("highest_unlocked", 1)), 1, level_count)
	return clampi(int(data.get("last_level", 1)), 1, highest)

func get_highest_unlocked() -> int:
	return clampi(int(data.get("highest_unlocked", 1)), 1, level_count)

func get_best_score(level_number: int) -> int:
	var scores = data.get("best_scores", {})
	if typeof(scores) != TYPE_DICTIONARY:
		return 0
	return maxi(0, int(scores.get(str(level_number), 0)))

func _record_best_score(level_number: int, final_score: int) -> void:
	var scores: Dictionary = data.get("best_scores", {})
	var key := str(level_number)
	scores[key] = maxi(int(scores.get(key, 0)), final_score)
	data["best_scores"] = scores

func _write_save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Cursor Hell: could not write save data.")
		return
	file.store_string(JSON.stringify(data, "\t"))

func _default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"highest_unlocked": 1,
		"last_level": 1,
		"best_scores": {}
	}
