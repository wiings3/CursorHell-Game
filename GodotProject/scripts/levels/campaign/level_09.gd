extends "res://scripts/levels/level_08.gd"

var camp_pressure := CursorHellCampPressureRuntime.new()

# Campaign adapter: DEAD ZONES keeps its approved gameplay and tuning unchanged
# while moving from the old Level 8 slot to Level 9 after Boss I is inserted.
func _reset_round(start_now: bool) -> void:
	super._reset_round(start_now)
	camp_pressure.reset(self)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	camp_pressure.update(self, delta)

func _get_level_number() -> int:
	return 9

func _get_intro_subtitle() -> String:
	return "LEVEL 9 — TERRITORY"

func _get_pause_subtitle() -> String:
	return "LEVEL 9 — DEAD ZONES"

func _get_death_subtitle() -> String:
	return "LEVEL 9 — SPACE DENIED"
