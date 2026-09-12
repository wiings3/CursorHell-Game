extends "res://scripts/levels/campaign/boss_02.gd"

var camp_pressure := CursorHellCampPressureRuntime.new()

func _reset_round(start_now: bool) -> void:
	super._reset_round(start_now)
	camp_pressure.reset(self)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	camp_pressure.update(self, delta)
