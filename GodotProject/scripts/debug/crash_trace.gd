extends RefCounted

const TRACE_PATH := "user://crash_trace.log"

static func reset() -> void:
	var file := FileAccess.open(TRACE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_line("=== CURSOR HELL CRASH TRACE ===")
	file.store_line("UTC: " + Time.get_datetime_string_from_system(true, true))
	file.store_line("OS: " + OS.get_name() + " " + OS.get_version())
	file.store_line("Godot: " + Engine.get_version_info().get("string", "unknown"))
	file.flush()

static func write(message: String) -> void:
	var file := FileAccess.open(TRACE_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(TRACE_PATH, FileAccess.WRITE)
		if file == null:
			return
	file.seek_end()
	file.store_line("[%d ms] %s" % [Time.get_ticks_msec(), message])
	file.flush()
	print("CRASH_TRACE: ", message)
