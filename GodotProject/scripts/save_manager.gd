extends RefCounted
class_name CursorHellSaveManager

const SAVE_PATH := "user://cursor_hell_save.json"
const SAVE_VERSION := 3
const BOSS_INSERT_LEVEL := 5

const RANK_VALUES := {
	"": 0,
	"F": 1,
	"D": 2,
	"C": 3,
	"B": 4,
	"A": 5,
	"S": 6,
	"S+": 7
}

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
		loaded_version = 2
		migrated = true
	if loaded_version < 3:
		loaded = _migrate_v2_to_v3(loaded)
		loaded_version = 3
		migrated = true

	data["version"] = SAVE_VERSION
	data["highest_unlocked"] = clampi(int(loaded.get("highest_unlocked", 1)), 1, level_count)
	data["last_level"] = clampi(int(loaded.get("last_level", 1)), 1, int(data["highest_unlocked"]))
	data["best_scores"] = _safe_dictionary_copy(loaded.get("best_scores", {}))
	data["best_times"] = _safe_dictionary_copy(loaded.get("best_times", {}))
	data["best_ranks"] = _safe_dictionary_copy(loaded.get("best_ranks", {}))

	has_existing_save = true
	if migrated:
		_write_save()

func record_level_started(level_number: int) -> void:
	var safe_level := clampi(level_number, 1, level_count)
	var highest := int(data.get("highest_unlocked", 1))
	data["last_level"] = mini(safe_level, highest)
	has_existing_save = true
	_write_save()

func record_level_result(
	level_number: int,
	final_score: int,
	completed: bool,
	survived_time: float = 0.0,
	rank: String = ""
) -> void:
	var safe_level := clampi(level_number, 1, level_count)
	_record_best_score(safe_level, final_score)
	_record_best_time(safe_level, survived_time)
	_record_best_rank(safe_level, rank)

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

func get_best_time(level_number: int) -> float:
	var times = data.get("best_times", {})
	if typeof(times) != TYPE_DICTIONARY:
		return 0.0
	return maxf(0.0, float(times.get(str(level_number), 0.0)))

func get_best_rank(level_number: int) -> String:
	var ranks = data.get("best_ranks", {})
	if typeof(ranks) != TYPE_DICTIONARY:
		return ""
	var rank := str(ranks.get(str(level_number), "")).to_upper()
	return rank if RANK_VALUES.has(rank) else ""

func _record_best_score(level_number: int, final_score: int) -> void:
	var scores: Dictionary = data.get("best_scores", {})
	var key := str(level_number)
	scores[key] = maxi(int(scores.get(key, 0)), final_score)
	data["best_scores"] = scores

func _record_best_time(level_number: int, survived_time: float) -> void:
	var times: Dictionary = data.get("best_times", {})
	var key := str(level_number)
	times[key] = maxf(float(times.get(key, 0.0)), maxf(survived_time, 0.0))
	data["best_times"] = times

func _record_best_rank(level_number: int, rank: String) -> void:
	var normalized := rank.strip_edges().to_upper()
	if not RANK_VALUES.has(normalized) or normalized.is_empty():
		return
	var ranks: Dictionary = data.get("best_ranks", {})
	var key := str(level_number)
	var previous := str(ranks.get(key, "")).to_upper()
	if int(RANK_VALUES[normalized]) > int(RANK_VALUES.get(previous, 0)):
		ranks[key] = normalized
	data["best_ranks"] = ranks

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
	migrated["version"] = 2
	return migrated

func _migrate_v2_to_v3(old_data: Dictionary) -> Dictionary:
	# v3 begins tracking survival time and performance rank. Older saves did not
	# contain enough information to reconstruct those stats reliably, so existing
	# scores/progression are preserved and the new records start empty.
	var migrated := old_data.duplicate(true)
	migrated["best_times"] = {}
	migrated["best_ranks"] = {}
	migrated["version"] = 3
	return migrated

func _safe_dictionary_copy(value) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value.duplicate(true)
	return {}

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
		"best_scores": {},
		"best_times": {},
		"best_ranks": {}
	}
