extends RefCounted
class_name CursorHellSaveManager

const SAVE_PATH := "user://cursor_hell_save.json"
const SAVE_VERSION := 2
const BOSS_INSERT_LEVEL := 5

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
	var loaded_version := int(loaded.get("version", 1))
	var migrated := false
	if loaded_version < 2:
		loaded = _migrate_v1_to_v2(loaded)
		migrated = true

	data["version"] = SAVE_VERSION
	data["highest_unlocked"] = clampi(int(loaded.get("highest_unlocked", 1)), 1, level_count)
	data["last_level"] = clampi(int(loaded.get("last_level", 1)), 1, int(data["highest_unlocked"]))

	var loaded_scores = loaded.get("best_scores", {})
	if typeof(loaded_scores) == TYPE_DICTIONARY:
		data["best_scores"] = loaded_scores.duplicate(true)
	else:
		data["best_scores"] = {}

	has_existing_save = true
	if migrated:
		_write_save()

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

func _migrate_v1_to_v2(old_data: Dictionary) -> Dictionary:
	# Save v2 inserts Boss I at campaign Level 5. Preserve every existing unlock,
	# continuation point and score by shifting the old Levels 5+ forward one slot.
	var migrated := old_data.duplicate(true)
	var old_highest := int(old_data.get("highest_unlocked", 1))
	var old_last := int(old_data.get("last_level", 1))

	migrated["highest_unlocked"] = old_highest + 1 if old_highest >= BOSS_INSERT_LEVEL else old_highest
	migrated["last_level"] = old_last + 1 if old_last >= BOSS_INSERT_LEVEL else old_last

	var shifted_scores: Dictionary = {}
	var old_scores = old_data.get("best_scores", {})
	if typeof(old_scores) == TYPE_DICTIONARY:
		for raw_key in old_scores.keys():
			var key_text := str(raw_key)
			if not key_text.is_valid_int():
				continue
			var old_level := int(key_text)
			var new_level := old_level + 1 if old_level >= BOSS_INSERT_LEVEL else old_level
			shifted_scores[str(new_level)] = old_scores[raw_key]

	migrated["best_scores"] = shifted_scores
	migrated["version"] = SAVE_VERSION
	return migrated

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
