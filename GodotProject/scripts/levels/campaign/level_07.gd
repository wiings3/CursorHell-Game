extends "res://scripts/levels/level_06.gd"

# Campaign adapter: THE FLOOD keeps its tested gameplay unchanged while moving
# from the old Level 6 slot to Level 7 after the first boss is inserted.
func _get_level_number() -> int:
	return 7

func _get_intro_subtitle() -> String:
	return "LEVEL 7 — PERSISTENCE"

func _get_pause_subtitle() -> String:
	return "LEVEL 7 — THE FLOOD"

func _get_death_subtitle() -> String:
	return "LEVEL 7 — SUBMERGED"
