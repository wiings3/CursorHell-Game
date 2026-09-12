extends "res://scripts/levels/level_05.gd"

# Campaign adapter: THE PULSE keeps its tested gameplay unchanged while moving
# from the old Level 5 slot to Level 6 after the first boss is inserted.
func _get_level_number() -> int:
	return 6

func _get_intro_subtitle() -> String:
	return "LEVEL 6 — TIMING"

func _get_pause_subtitle() -> String:
	return "LEVEL 6 — THE PULSE"

func _get_death_subtitle() -> String:
	return "LEVEL 6 — OFF BEAT"
