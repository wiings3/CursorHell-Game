extends "res://scripts/levels/level_08.gd"

# Campaign adapter: DEAD ZONES keeps its approved gameplay and tuning unchanged
# while moving from the old Level 8 slot to Level 9 after Boss I is inserted.
func _get_level_number() -> int:
	return 9

func _get_intro_subtitle() -> String:
	return "LEVEL 9 — TERRITORY"

func _get_pause_subtitle() -> String:
	return "LEVEL 9 — DEAD ZONES"

func _get_death_subtitle() -> String:
	return "LEVEL 9 — SPACE DENIED"
