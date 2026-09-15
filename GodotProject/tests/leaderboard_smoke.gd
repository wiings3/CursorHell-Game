# Run after editor import: godot --headless --path GodotProject --script res://tests/leaderboard_smoke.gd
extends SceneTree

const LeaderboardScene := preload("res://Scenes/UI/LeaderboardMenu.tscn")
const ServiceScript := preload("res://scripts/online/leaderboard_service.gd")

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var service := ServiceScript.new() as CursorHellLeaderboardService
	root.add_child(service)
	await process_frame
	check(service != null, "Leaderboard service must instantiate.")
	check(not service.player_id.is_empty(), "Leaderboard service must create a persistent player id.")
	check(service.player_id.length() == 36, "Leaderboard player id must be UUID-shaped.")
	check(not service.player_secret.is_empty(), "Leaderboard service must create a private submission token.")
	check(service.player_secret.length() == 36, "Leaderboard submission token must be UUID-shaped.")
	check(service.player_secret != service.player_id, "Public player id and private submission token must differ.")
	check(service.is_valid_callsign("PLAYER-01"), "Expected callsign characters should be accepted.")
	check(not service.is_valid_callsign(""), "Empty callsigns must be rejected.")
	check(not service.is_valid_callsign("THIS_CALLSIGN_IS_WAY_TOO_LONG"), "Callsigns over 16 characters must be rejected.")
	check(not service.is_valid_callsign("BAD@NAME"), "Unsupported callsign characters must be rejected.")

	var menu := LeaderboardScene.instantiate() as CursorHellLeaderboardMenu
	root.add_child(menu)
	await process_frame
	check(menu != null, "Leaderboard menu must instantiate.")
	check(menu.get_node_or_null("Root/PanelGroup/Panel/VBox/BoardTabs/SurvivalButton") != null, "Survival tab is missing.")
	check(menu.get_node_or_null("Root/PanelGroup/Panel/VBox/BoardTabs/ScoreButton") != null, "Score tab is missing.")
	check(menu.get_node_or_null("Root/PanelGroup/Panel/VBox/CallsignRow/CallsignEdit") != null, "Callsign field is missing.")

	menu.queue_free()
	service.queue_free()
	await process_frame
	print("LEADERBOARD CHECKS COMPLETE: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
