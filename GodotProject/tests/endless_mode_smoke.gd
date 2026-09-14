# Run after editor import: godot --headless --path GodotProject --script res://tests/endless_mode_smoke.gd
extends SceneTree

const EndlessScene := preload("res://Scenes/Modes/EndlessMode.tscn")
const ScoreTargetScene := preload("res://Scenes/Components/ScoreTarget.tscn")

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
	var target_runtime := endless.get_node("TargetRuntime") as CursorHellEndlessTargetRuntime
	check(target_runtime != null, "Endless score target runtime is missing.")
	if target_runtime != null:
		check(target_runtime.CHAIN_LENGTH == 4, "Endless target chains must contain four targets.")
		check(target_runtime.CHAIN_SCORES.size() == target_runtime.CHAIN_LENGTH, "Every chain step must define a score reward.")
		check(target_runtime.CHAIN_PURGE_RADII.size() == target_runtime.CHAIN_LENGTH, "Every chain step must define a purge radius.")
		check(float(target_runtime.CHAIN_PURGE_RADII[3]) > float(target_runtime.CHAIN_PURGE_RADII[0]), "The chain finisher purge must be larger than the opening purge.")
		check(int(target_runtime.CHAIN_SCORES[3]) > int(target_runtime.CHAIN_SCORES[0]), "The chain finisher must be worth more than the opening target.")

	check(str(endless._timeline_at(0.0)["kind"]) == "prepare", "0:00 must begin in PREPARE.")
	check(str(endless._timeline_at(4.99)["kind"]) == "prepare", "First five seconds must remain downtime.")
	check(str(endless._timeline_at(5.0)["kind"]) == "normal" and int(endless._timeline_at(5.0)["phase"]) == 1, "Phase 1 must begin at 0:05.")
	check(int(endless._timeline_at(64.9)["phase"]) == 5, "The first set must contain five 12-second normal phases.")
	check(str(endless._timeline_at(65.0)["kind"]) == "boss" and int(endless._timeline_at(65.0)["boss"]) == 1, "Boss 1 must begin around the one-minute mark after Phase 5.")
	check(str(endless._timeline_at(95.0)["kind"]) == "breather", "Boss clear must enter the five-second breather.")
	check(int(endless._timeline_at(95.0)["bosses_cleared"]) == 1, "Boss clear must advance the cleared-boss count.")
	check(str(endless._timeline_at(100.0)["kind"]) == "normal" and int(endless._timeline_at(100.0)["phase"]) == 6, "Phase 6 must begin after the boss breather.")
	check(int(endless._timeline_at(100.0)["tier"]) == 2, "Boss 1 must advance the threat tier.")
	check(endless._pattern_pool_for_tier(1).size() >= 4, "Tier 1 must have multiple phase patterns.")
	check(endless._pattern_pool_for_tier(2).size() >= 5, "Tier 2 must replace the opening pool with broader pressure patterns.")
	check(endless._pattern_pool_for_tier(4).has("TIGHT WARNING"), "High tiers must retain advanced pressure patterns.")
	check(endless._normal_speed(1, 1) >= 165.0, "Phase 1 must begin at meaningful Endless pressure.")
	endless.elapsed = 5.0
	check(endless._get_spawn_interval(1) <= 1.40, "Opening Endless cadence must not use the old slow spawn rate.")
	endless.elapsed = 0.0

	var target := ScoreTargetScene.instantiate() as CursorHellScoreTarget
	check(target != null, "ScoreTarget.tscn must use CursorHellScoreTarget.")
	if target != null:
		root.add_child(target)
		await process_frame
		check(target.score_bonus > 0, "Score targets must award a score bonus.")
		check(target.purge_radius > target.hit_radius, "Score target purge radius must be larger than its click radius.")
		target.configure_chain(4, 4, 2.35, 220.0, 2500)
		check(target.chain_step == 4, "Score target must accept finisher chain state.")
		check(target.purge_radius == 220.0, "Score target finisher purge radius must be configurable.")
		check(target.score_bonus == 2500, "Score target finisher score must be configurable.")
		check(target.get_node("StageLabel") != null, "Score target must show its chain stage.")
		root.remove_child(target)
		target.queue_free()

	endless._reset_round(true)
	check(endless.state == "playing", "Endless must start its 0:00 prepare window without the campaign countdown.")
	check(endless._get_phase() == 0, "Prepare window must not spawn threats.")

	root.remove_child(endless)
	endless.queue_free()
	await process_frame
	print("ENDLESS CHECKS COMPLETE: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
