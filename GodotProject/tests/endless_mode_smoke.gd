# Run after editor import: godot --headless --path GodotProject --script res://tests/endless_mode_smoke.gd
extends SceneTree

const EndlessScene := preload("res://Scenes/Modes/EndlessMode.tscn")

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var endless = EndlessScene.instantiate()
	root.add_child(endless)
	await process_frame

	check(endless is CursorHellBaseLevel, "Endless Mode must reuse CursorHellBaseLevel.")
	check(endless.get_node("LevelHUD/ScreenUI/EndlessPhaseHUD") != null, "Endless phase HUD is missing.")
	check(str(endless._timeline_at(0.0)["kind"]) == "prepare", "0:00 must begin in PREPARE.")
	check(str(endless._timeline_at(4.99)["kind"]) == "prepare", "First five seconds must remain downtime.")
	check(str(endless._timeline_at(5.0)["kind"]) == "normal" and int(endless._timeline_at(5.0)["phase"]) == 1, "Phase 1 must begin at 0:05.")
	check(int(endless._timeline_at(129.9)["phase"]) == 5, "The first set must contain five normal phases.")
	check(str(endless._timeline_at(130.0)["kind"]) == "boss" and int(endless._timeline_at(130.0)["boss"]) == 1, "Boss 1 must follow Phase 5.")
	check(str(endless._timeline_at(160.0)["kind"]) == "breather", "Boss clear must enter the five-second breather.")
	check(int(endless._timeline_at(160.0)["bosses_cleared"]) == 1, "Boss clear must advance the cleared-boss count.")
	check(str(endless._timeline_at(165.0)["kind"]) == "normal" and int(endless._timeline_at(165.0)["phase"]) == 6, "Phase 6 must begin after the boss breather.")
	check(int(endless._timeline_at(165.0)["tier"]) == 2, "Boss 1 must advance the threat tier.")

	endless._reset_round(true)
	check(endless.state == "playing", "Endless must start its 0:00 prepare window without the campaign countdown.")
	check(endless._get_phase() == 0, "Prepare window must not spawn threats.")

	root.remove_child(endless)
	endless.queue_free()
	await process_frame
	print("ENDLESS CHECKS COMPLETE: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
