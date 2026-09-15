extends Node
class_name CursorHellLeaderboardService

signal leaderboard_loaded(board: String, rows: Array)
signal leaderboard_failed(message: String)
signal submission_finished(ok: bool, message: String)

const CONFIG_PATH := "res://leaderboard_config.json"
const PROFILE_PATH := "user://cursor_hell_online.cfg"
const PROFILE_SECTION := "profile"

var supabase_url := ""
var anon_key := ""
var configured := false
var player_id := ""
var player_secret := ""
var callsign := ""

func _ready() -> void:
	_load_config()
	_load_profile()

func _load_config() -> void:
	var env_url := OS.get_environment("CURSORHELL_SUPABASE_URL").strip_edges()
	var env_key := OS.get_environment("CURSORHELL_SUPABASE_ANON_KEY").strip_edges()
	if not env_url.is_empty() and not env_key.is_empty():
		supabase_url = env_url.trim_suffix("/")
		anon_key = env_key
		configured = true
		return
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	supabase_url = str(parsed.get("url", "")).strip_edges().trim_suffix("/")
	anon_key = str(parsed.get("anon_key", "")).strip_edges()
	configured = not supabase_url.is_empty() and not anon_key.is_empty() and not supabase_url.contains("YOUR_PROJECT")

func _load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(PROFILE_PATH) == OK:
		player_id = str(config.get_value(PROFILE_SECTION, "player_id", "")).strip_edges()
		player_secret = str(config.get_value(PROFILE_SECTION, "player_secret", "")).strip_edges()
		callsign = str(config.get_value(PROFILE_SECTION, "callsign", "")).strip_edges().left(16)
	var changed := false
	if player_id.is_empty():
		player_id = _generate_uuid_v4()
		changed = true
	if player_secret.is_empty():
		player_secret = _generate_uuid_v4()
		changed = true
	if changed:
		_save_profile()

func set_callsign(value: String) -> bool:
	var clean := value.strip_edges().left(16)
	if not is_valid_callsign(clean):
		return false
	callsign = clean
	_save_profile()
	return true

func is_valid_callsign(value: String) -> bool:
	if value.length() < 1 or value.length() > 16:
		return false
	var allowed := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 _.-"
	for index in range(value.length()):
		if allowed.find(value.substr(index, 1)) < 0:
			return false
	return true

func can_submit() -> bool:
	return configured and not player_id.is_empty() and not player_secret.is_empty() and is_valid_callsign(callsign)

func submit_endless(summary: Dictionary) -> void:
	if not configured:
		submission_finished.emit(false, "ONLINE SERVICE NOT CONFIGURED")
		return
	if not is_valid_callsign(callsign):
		submission_finished.emit(false, "SET A CALLSIGN BEFORE SUBMITTING")
		return
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(func(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		request.queue_free()
		var ok := code >= 200 and code < 300
		var message := "SUBMITTED" if ok else _error_message(body, code)
		submission_finished.emit(ok, message)
	)
	var payload := {
		"p_player_id": player_id,
		"p_player_secret": player_secret,
		"p_callsign": callsign,
		"p_survival_ms": int(round(float(summary.get("time", 0.0)) * 1000.0)),
		"p_score": int(summary.get("score", 0)),
		"p_phase": int(summary.get("phase", 0))
	}
	var error := request.request(
		supabase_url + "/rest/v1/rpc/submit_endless_result",
		_headers(), HTTPClient.METHOD_POST, JSON.stringify(payload)
	)
	if error != OK:
		request.queue_free()
		submission_finished.emit(false, "NETWORK REQUEST FAILED")

func fetch_board(board: String, limit: int = 50) -> void:
	if not configured:
		leaderboard_failed.emit("ONLINE SERVICE NOT CONFIGURED")
		return
	var safe_board := "score" if board == "score" else "survival"
	var order := "best_score.desc,score_survival_ms.desc" if safe_board == "score" else "best_survival_ms.desc,survival_score.desc"
	var url := supabase_url + "/rest/v1/endless_leaderboard_public?select=player_id,callsign,best_survival_ms,survival_score,survival_phase,best_score,score_survival_ms,score_phase&order=" + order + "&limit=" + str(clampi(limit, 1, 100))
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(func(_result: int, code: int, _headers_out: PackedStringArray, body: PackedByteArray) -> void:
		request.queue_free()
		if code < 200 or code >= 300:
			leaderboard_failed.emit(_error_message(body, code))
			return
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if typeof(parsed) != TYPE_ARRAY:
			leaderboard_failed.emit("INVALID LEADERBOARD RESPONSE")
			return
		leaderboard_loaded.emit(safe_board, parsed)
	)
	var error := request.request(url, _headers(), HTTPClient.METHOD_GET)
	if error != OK:
		request.queue_free()
		leaderboard_failed.emit("NETWORK REQUEST FAILED")

func _headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: " + anon_key,
		"Authorization: Bearer " + anon_key,
		"Content-Type: application/json"
	])

func _save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value(PROFILE_SECTION, "player_id", player_id)
	config.set_value(PROFILE_SECTION, "player_secret", player_secret)
	config.set_value(PROFILE_SECTION, "callsign", callsign)
	var error := config.save(PROFILE_PATH)
	if error != OK:
		push_warning("Cursor Hell: could not save online leaderboard profile.")

func _generate_uuid_v4() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	if bytes.size() != 16:
		return "%08x-%04x-4%03x-a%03x-%012x" % [Time.get_ticks_msec() & 0xFFFFFFFF, randi() & 0xFFFF, randi() & 0xFFF, randi() & 0xFFF, randi() & 0xFFFFFFFFFFFF]
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]

func _error_message(body: PackedByteArray, code: int) -> String:
	var text := body.get_string_from_utf8().strip_edges()
	if text.length() > 120:
		text = text.left(120)
	return "ONLINE ERROR %d%s" % [code, "  //  " + text if not text.is_empty() else ""]
