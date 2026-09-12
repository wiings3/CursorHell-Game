extends "res://scripts/levels/level_07.gd"

# Campaign adapter: AFTERSHOCK keeps its tested gameplay unchanged while moving
# from the old Level 7 slot to Level 8 after the first boss is inserted.
func _get_level_number() -> int:
	return 8

func _get_intro_subtitle() -> String:
	return "LEVEL 8 — MEMORY"

func _get_pause_subtitle() -> String:
	return "LEVEL 8 — AFTERSHOCK"

func _get_death_subtitle() -> String:
	return "LEVEL 8 — CAUGHT IN THE ECHO"
