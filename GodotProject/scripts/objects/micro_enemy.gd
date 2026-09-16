extends Node2D
class_name CursorHellMicroEnemy

signal fire_requested(enemy: Node2D, locked_target: Vector2, pattern: String)

var kind := "gunner"
var hit_radius := 24.0
var score_value := 1000
var spawn_duration := 0.20
var spawn_time := 0.20
var initial_delay := 0.60
var repeat_delay := 1.25
var fire_timer := 0.60
var lock_window := 0.30
var locked_target := Vector2.ZERO
var has_lock := false
var active_age := 0.0
var pulse := 0.0
var dead := false

func configure(config: Dictionary) -> void:
	kind = str(config.get("kind", "gunner"))
	hit_radius = maxf(float(config.get("radius", 24.0)), 10.0)
	score_value = int(config.get("score", 1000))
	spawn_duration = maxf(float(config.get("spawn", 0.20)), 0.01)
	spawn_time = spawn_duration
	initial_delay = maxf(float(config.get("initial", 0.60)), 0.08)
	repeat_delay = maxf(float(config.get("repeat", 1.25)), 0.35)
	lock_window = float(config.get("lock", _default_lock_window(kind)))
	fire_timer = initial_delay
	active_age = 0.0
	has_lock = false
	dead = false
	queue_redraw()

func advance(delta: float, target_position: Vector2) -> void:
	if dead:
		return

	pulse += delta * 5.0
	if spawn_time > 0.0:
		spawn_time = maxf(0.0, spawn_time - delta)
		queue_redraw()
		return

	active_age += delta
	fire_timer -= delta

	if not has_lock and fire_timer <= lock_window:
		locked_target = target_position
		has_lock = true

	if fire_timer <= 0.0:
		if not has_lock:
			locked_target = target_position
		fire_requested.emit(self, locked_target, kind)
		fire_timer = repeat_delay
		has_lock = false

	queue_redraw()

func contains_point(point: Vector2) -> bool:
	return is_active() and position.distance_to(point) <= hit_radius

func is_active() -> bool:
	return not dead and spawn_time <= 0.0

func kill() -> void:
	dead = true
	has_lock = false
	queue_redraw()

func _default_lock_window(enemy_kind: String) -> float:
	match enemy_kind:
		"burst":
			return 0.38
		"sniper":
			return 0.46
		_:
			return 0.30

func _draw() -> void:
	var spawn_ratio := 1.0
	if spawn_duration > 0.0 and spawn_time > 0.0:
		spawn_ratio = clampf(1.0 - spawn_time / spawn_duration, 0.18, 1.0)

	var outer := Color(1.0, 0.42, 0.12, 0.96)
	var core := Color(1.0, 0.86, 0.42, 1.0)
	var warning := Color(1.0, 0.20, 0.08, 0.76)
	match kind:
		"burst":
			outer = Color(0.92, 0.32, 0.92, 0.96)
			core = Color(1.0, 0.78, 1.0, 1.0)
			warning = Color(1.0, 0.30, 0.72, 0.78)
		"sniper":
			outer = Color(1.0, 0.70, 0.18, 0.98)
			core = Color(1.0, 0.96, 0.72, 1.0)
			warning = Color(1.0, 0.58, 0.12, 0.82)

	if dead:
		outer.a = 0.18
		core.a = 0.18

	if has_lock and not dead:
		var local_target := locked_target - position
		draw_line(Vector2.ZERO, local_target, Color(warning.r, warning.g, warning.b, 0.26), 2.0, true)
		var lock_progress := clampf(1.0 - fire_timer / maxf(lock_window, 0.001), 0.0, 1.0)
		draw_circle(local_target, 4.0 + lock_progress * 3.0, Color(warning.r, warning.g, warning.b, 0.62), false, 1.5, true)

	var radius := hit_radius * spawn_ratio
	var diamond := PackedVector2Array([
		Vector2(0.0, -radius),
		Vector2(radius, 0.0),
		Vector2(0.0, radius),
		Vector2(-radius, 0.0)
	])
	draw_colored_polygon(diamond, Color(outer.r, outer.g, outer.b, 0.16))
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), outer, 2.5, true)
	draw_circle(Vector2.ZERO, maxf(4.0, radius * 0.28), core)
	draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 32, Color(outer.r, outer.g, outer.b, 0.54), 1.5, true)

	if spawn_time <= 0.0 and not dead:
		var pulse_radius := radius + 10.0 + sin(pulse) * 2.0
		draw_arc(Vector2.ZERO, pulse_radius, -PI * 0.30, PI * 0.30, 12, Color(outer.r, outer.g, outer.b, 0.42), 2.0, true)
