extends RefCounted
class_name CursorHellLevelCatalog

# Canonical campaign registry. Menus/loaders should read identity and scene data
# from here instead of maintaining parallel level-name or scene arrays.
const LEVELS := [
	{
		"number": 1,
		"name": "FIRST CONTACT",
		"boss_tag": "",
		"is_boss": false,
		"round_time": 45.0,
		"scene": preload("res://Scenes/Levels/Level1.tscn")
	},
	{
		"number": 2,
		"name": "CROSSFIRE",
		"boss_tag": "",
		"is_boss": false,
		"round_time": 45.0,
		"scene": preload("res://Scenes/Levels/Level2.tscn")
	},
	{
		"number": 3,
		"name": "THE SWEEP",
		"boss_tag": "",
		"is_boss": false,
		"round_time": 45.0,
		"scene": preload("res://Scenes/Levels/Level3.tscn")
	},
	{
		"number": 4,
		"name": "THE GAP",
		"boss_tag": "",
		"is_boss": false,
		"round_time": 60.0,
		"scene": preload("res://Scenes/Levels/Level4.tscn")
	},
	{
		"number": 5,
		"name": "SYNTHESIS",
		"boss_tag": "BOSS I",
		"is_boss": true,
		"round_time": 60.0,
		"scene": preload("res://Scenes/Campaign/Boss1.tscn")
	},
	{
		"number": 6,
		"name": "THE PULSE",
		"boss_tag": "",
		"is_boss": false,
		"round_time": 60.0,
		"scene": preload("res://Scenes/Campaign/Level6.tscn")
	},
	{
		"number": 7,
		"name": "THE FLOOD",
		"boss_tag": "",
		"is_boss": false,
		"round_time": 60.0,
		"scene": preload("res://Scenes/Campaign/Level7.tscn")
	},
	{
		"number": 8,
		"name": "AFTERSHOCK",
		"boss_tag": "",
		"is_boss": false,
		"round_time": 60.0,
		"scene": preload("res://Scenes/Campaign/Level8.tscn")
	},
	{
		"number": 9,
		"name": "DEAD ZONES",
		"boss_tag": "",
		"is_boss": false,
		"round_time": 60.0,
		"scene": preload("res://Scenes/Campaign/Level9.tscn")
	},
	{
		"number": 10,
		"name": "CONVERGENCE",
		"boss_tag": "BOSS II",
		"is_boss": true,
		"round_time": 60.0,
		"scene": preload("res://Scenes/Campaign/Boss2.tscn")
	}
]

static func count() -> int:
	return LEVELS.size()

static func get_level(index: int) -> Dictionary:
	if index < 0 or index >= LEVELS.size():
		push_error("Cursor Hell: level catalog index %d is out of range." % index)
		return {}
	return LEVELS[index]

static func get_scene(index: int) -> PackedScene:
	var metadata := get_level(index)
	if metadata.is_empty():
		return null
	return metadata.get("scene") as PackedScene
