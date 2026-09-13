# Run after editor import: godot --headless --path GodotProject --script res://tests/cabinet_layout_smoke.gd
extends SceneTree

const Catalog = preload("res://scripts/level_catalog.gd")
const OBSOLETE_LEVEL_SCENES := [
	"res://Scenes/Levels/Level1.tscn",
	"res://Scenes/Levels/Level2.tscn",
	"res://Scenes/Levels/Level3.tscn",
	"res://Scenes/Levels/Level4.tscn",
	"res://Scenes/Levels/Level5.tscn",
	"res://Scenes/Levels/Level6.tscn",
	"res://Scenes/Levels/Level7.tscn",
	"res://Scenes/Levels/Level8.tscn"
]

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func canvas_rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

func _check_catalog_integrity() -> void:
	var seen_paths := {}
	for index in range(Catalog.count()):
		var packed_scene: PackedScene = Catalog.get_scene(index)
		var scene_path := packed_scene.resource_path
		check(not scene_path.is_empty(), "Catalog scene has no resource path: %d" % index)
		check(scene_path.begins_with("res://Scenes/Campaign/"), "Campaign scene outside canonical folder: %s" % scene_path)
		check(not seen_paths.has(scene_path), "Duplicate scene registered in LevelCatalog: %s" % scene_path)
		seen_paths[scene_path] = true

	for scene_path in OBSOLETE_LEVEL_SCENES:
		check(not ResourceLoader.exists(scene_path), "Obsolete level scene still exists: %s" % scene_path)

func _run() -> void:
	_check_catalog_integrity()

	for index in range(Catalog.count()):
		var level = Catalog.get_scene(index).instantiate()
		level.configure_level_metadata(Catalog.get_level(index))
		root.add_child(level)
		await process_frame
		level.set_physics_process(false)
		var shell = level.machine_shell
		var hud = level.hud
		var metadata: Dictionary = Catalog.get_level(index)
		var hint_label := hud.get_node("HintLabel") as Control

		check(level.state == "intro", "Intro missing: %d" % index)
		check(hud.screen_ui.get_rect().is_equal_approx(shell.get_layout_rect(shell.screen)), "Screen HUD local alignment: %d" % index)
		check(canvas_rect(hud.screen_ui).is_equal_approx(canvas_rect(shell.screen)), "Screen HUD canvas alignment: %d" % index)
		check(canvas_rect(hud.timer_readout).is_equal_approx(canvas_rect(shell.timer_area)), "Timer HUD alignment: %d" % index)
		check(canvas_rect(hud.score_readout).is_equal_approx(canvas_rect(shell.score_area)), "Score HUD alignment: %d" % index)
		check(canvas_rect(hud.identity_row).is_equal_approx(canvas_rect(shell.identity_area)), "Identity HUD alignment: %d" % index)
		check(canvas_rect(hud.tutorial_label).is_equal_approx(canvas_rect(shell.tutorial_area)), "Tutorial HUD alignment: %d" % index)
		check(hint_label != null and canvas_rect(hint_label).is_equal_approx(canvas_rect(shell.hint_area)), "Hint HUD alignment: %d" % index)
		check(canvas_rect(shell.crt_overlay).is_equal_approx(canvas_rect(shell.screen)), "CRT screen alignment: %d" % index)
		check(shell.screen.clip_contents and hud.screen_ui.clip_contents, "Clipping missing: %d" % index)
		check(hud.tutorial_label.size.y >= 56.0, "Tutorial panel is too short for two lines: %d" % index)
		check(level.player.get_parent() == shell.arena_content, "Player canvas: %d" % index)
		check(level.projectile_layer.get_parent() == shell.arena_content, "Projectile canvas: %d" % index)
		check(level.warning_layer.get_parent() == shell.arena_content, "Warning canvas: %d" % index)
		check(hud.level_name_label.text == str(metadata.get("name", "")), "Level identity: %d" % index)
		check(hud.boss_tag_label.text == str(metadata.get("boss_tag", "")), "Boss tag text: %d" % index)
		check(hud.boss_tag_label.visible == bool(metadata.get("is_boss", false)), "Boss identity visibility: %d" % index)

		level._reset_round(true)
		check(level.state == "countdown", "Countdown missing: %d" % index)
		var start: Vector2 = level.player.position
		var arena_transform: Transform2D = shell.arena_content.get_global_transform_with_canvas()
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(61, 47)
		level._input(motion)
		var displayed_motion: Vector2 = arena_transform.basis_xform(level.player.position - start)
		check(displayed_motion.is_equal_approx(motion.relative), "Mouse mapping: %d" % index)

		for side in range(4):
			level.queue_projectile_warning(side, 0.5, 300.0, 10.0, 1.0)
		level.warning_layer._sync_warning_markers()
		check(level.warning_layer.runtime_markers.get_child_count() == 4, "Warnings: %d" % index)

		level._update_countdown(4.0)
		level.score = 1234567
		level._update_ui()
		hud._fit_score_readout()
		check(hud.score_label.text == "1,234,567", "Live score: %d" % index)
		var font: Font = hud.score_label.get_theme_font("font")
		check(font.get_string_size(hud.score_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, hud.score_label.get_theme_font_size("font_size")).x * 1.08 <= hud.score_label.size.x, "Score overflow: %d" % index)

		level._begin_death("Layout test")
		hud._sync_message_prompt()
		check(hud.hit_label.position.x >= 0 and hud.hit_label.position.y >= 0, "Impact popup: %d" % index)
		level._show_death_panel()
		check(level.state == "dead" and hud.message_panel.visible, "Death panel: %d" % index)
		level._reset_round(true)
		level._update_countdown(4.0)
		level._win()
		check(level.state == "won" and hud.message_panel.visible, "Completion panel: %d" % index)
		print("PASS campaign ", index + 1, " ", str(metadata.get("name", "")))
		root.remove_child(level)
		level.queue_free()
		await process_frame

	await check_main_layout()
	print("CHECKS COMPLETE: ", failures.size(), " failures")
	await create_timer(0.25).timeout
	quit(0 if failures.is_empty() else 1)

func check_main_layout() -> void:
	var main = load("res://Scenes/Main.tscn").instantiate()
	main.show_main_menu_on_launch = false
	root.add_child(main)
	await process_frame
	main._begin_current_round()
	main.current_level.set_physics_process(false)
	root.content_scale_size = Vector2i.ZERO

	for window_size in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1280, 960)]:
		root.size = window_size
		await process_frame
		await process_frame
		var level = main.current_level
		var shell = level.machine_shell
		var hud = level.hud
		var screen: Control = shell.screen
		var screen_transform: Transform2D = screen.get_global_transform_with_canvas()
		var hud_screen_transform: Transform2D = hud.screen_ui.get_global_transform_with_canvas()
		var crt_transform: Transform2D = shell.crt_overlay.get_global_transform_with_canvas()
		var transition_transform: Transform2D = main.transition_overlay.root.get_global_transform_with_canvas()
		var pause_root: Control = main.pause_menu.get_node("Root")
		var pause_transform: Transform2D = pause_root.get_global_transform_with_canvas()

		check(screen_transform.is_equal_approx(hud_screen_transform), "HUD canvas alignment at %s" % window_size)
		check(screen_transform.is_equal_approx(crt_transform), "CRT canvas alignment at %s" % window_size)
		check(screen_transform.is_equal_approx(transition_transform), "Campaign overlay alignment at %s" % window_size)
		check(screen_transform.is_equal_approx(pause_transform), "Pause alignment at %s" % window_size)
		check(screen.size.is_equal_approx(pause_root.size), "Pause clipping bounds at %s" % window_size)
		check(canvas_rect(hud.tutorial_label).is_equal_approx(canvas_rect(shell.tutorial_area)), "Tutorial alignment at %s" % window_size)
		check(canvas_rect(hud.identity_row).is_equal_approx(canvas_rect(shell.identity_area)), "Identity alignment at %s" % window_size)

		level._reset_player_position()
		var start: Vector2 = level.player.position
		var canvas_transform: Transform2D = shell.arena_content.get_global_transform_with_canvas()
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(71, -43)
		level._input(motion)
		check(canvas_transform.basis_xform(level.player.position - start).distance_to(motion.relative) < 0.01, "Mouse conversion at %s" % window_size)

	root.remove_child(main)
	main.queue_free()
	await process_frame
