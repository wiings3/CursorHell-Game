extends Node
class_name CursorHellEndlessTargetRuntime

const ScoreTargetScene := preload("res://Scenes/Components/ScoreTarget.tscn")
const SfxScript = preload("res://scripts/sfx.gd")
const ARENA := CursorHellMachineShell.LOGICAL_ARENA
const CHAIN_LENGTH := 4
const CHAIN_SCORES := [500, 1000, 1500, 2500]
const CHAIN_PURGE_RADII := [120.0, 140.0, 165.0, 220.0]
const CHAIN_LIFETIMES := [5.5, 2.7, 2.5, 2.35]
const FINISHER_BONUS := 3000
const HIT_STOP_TIME := 0.045

@export var first_spawn_delay: float = 7.0
@export var min_spawn_delay: float = 9.0
@export var max_spawn_delay: float = 14.0
@export var projectile_clear_bonus: int = 250
@export var spawn_edge_margin: float = 105.0
@export var min_player_distance: float = 150.0
@export var min_chain_jump_distance: float = 245.0

var level: CursorHellEndlessMode
var active_target: CursorHellScoreTarget
var spawn_clock := 7.0
var last_elapsed := 0.0
var chain_active := false
var chain_step := 0
var last_target_position := Vector2.ZERO

func _ready() -> void:
	level = get_parent() as CursorHellEndlessMode
	if level == null:
		push_error("Cursor Hell: EndlessTargetRuntime must be a child of CursorHellEndlessMode.")
		set_process(false)
		set_process_unhandled_input(false)
		return
	spawn_clock = first_spawn_delay
	last_elapsed = level.elapsed

func _process(delta: float) -> void:
	if not is_instance_valid(level):
		return

	if level.elapsed + 0.01 < last_elapsed:
		_reset_runtime()
	last_elapsed = level.elapsed

	if level.state != "playing":
		_clear_target()
		_reset_chain(false)
		return

	var info: Dictionary = level._timeline_at(level.elapsed)
	var kind := str(info.get("kind", ""))
	if kind == "prepare" or kind == "breather":
		_clear_target()
		_reset_chain(false)
		return

	if is_instance_valid(active_target):
		return

	if chain_active:
		return

	spawn_clock -= delta
	if spawn_clock <= 0.0:
		_spawn_chain_target(1, false)

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(level) or level.state != "playing":
		return
	if not is_instance_valid(active_target):
		return
	if not (event is InputEventMouseButton):
		return

	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or not mouse_button.pressed:
		return

	if active_target.contains_point(level.player.global_position):
		_activate_target()
		get_viewport().set_input_as_handled()

func _spawn_chain_target(step: int, force_different_region: bool) -> void:
	var target := ScoreTargetScene.instantiate() as CursorHellScoreTarget
	if target == null:
		push_error("Cursor Hell: ScoreTarget.tscn must use CursorHellScoreTarget.")
		return

	var safe_step := clampi(step, 1, CHAIN_LENGTH)
	var position_hint := last_target_position
	level.projectile_layer.add_child(target)
	target.position = _choose_spawn_position(position_hint, force_different_region)
	target.configure_chain(
		safe_step,
		CHAIN_LENGTH,
		float(CHAIN_LIFETIMES[safe_step - 1]),
		float(CHAIN_PURGE_RADII[safe_step - 1]),
		int(CHAIN_SCORES[safe_step - 1])
	)
	target.expired.connect(_on_target_expired)
	active_target = target
	chain_step = safe_step
	last_target_position = target.position

	if safe_step == 1:
		chain_active = false
		spawn_clock = level.rng.randf_range(min_spawn_delay, max_spawn_delay)
	else:
		chain_active = true

func _choose_spawn_position(previous_position: Vector2, force_different_region: bool) -> Vector2:
	var left := ARENA.position.x + spawn_edge_margin
	var right := ARENA.end.x - spawn_edge_margin
	var top := ARENA.position.y + spawn_edge_margin
	var bottom := ARENA.end.y - spawn_edge_margin
	var candidate := ARENA.get_center()
	var previous_quadrant := _quadrant(previous_position)

	for _attempt in range(18):
		candidate = Vector2(
			level.rng.randf_range(left, right),
			level.rng.randf_range(top, bottom)
		)
		if candidate.distance_to(level.player.position) < min_player_distance:
			continue
		if force_different_region:
			if candidate.distance_to(previous_position) < min_chain_jump_distance:
				continue
			if _quadrant(candidate) == previous_quadrant:
				continue
		break
	return candidate

func _quadrant(point: Vector2) -> int:
	var center := ARENA.get_center()
	var right_side := point.x >= center.x
	var bottom_side := point.y >= center.y
	if right_side and bottom_side:
		return 3
	if right_side:
		return 1
	if bottom_side:
		return 2
	return 0

func _activate_target() -> void:
	if not is_instance_valid(active_target):
		return

	var target := active_target
	var completed_step := target.chain_step
	var target_position := target.position
	var target_global := target.global_position
	active_target = null

	var cleared := _purge_projectiles(target_global, target.purge_radius)
	var bonus := target.score_bonus + cleared * projectile_clear_bonus
	var chain_complete := completed_step >= CHAIN_LENGTH
	if chain_complete:
		bonus += FINISHER_BONUS

	level.score += bonus
	level.score_punch = 1.0
	level.run_stats.update_live(level.elapsed, int(level.score))
	_spawn_purge_wave(target_position, target.purge_radius, chain_complete)
	_show_target_feedback(target_position, completed_step, bonus, cleared, chain_complete)
	SfxScript.play_graze(level, completed_step)
	target.consume()
	_start_hit_stop()

	if chain_complete:
		chain_active = false
		chain_step = 0
		spawn_clock = level.rng.randf_range(min_spawn_delay, max_spawn_delay)
	else:
		chain_active = true
		_spawn_chain_target(completed_step + 1, true)

func _purge_projectiles(center: Vector2, radius: float) -> int:
	var cleared := 0
	var pop_count := 0
	for child in level.projectile_layer.get_children():
		var projectile := child as CursorHellProjectile
		if projectile == null or not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
			continue
		if projectile.global_position.distance_to(center) <= radius + projectile.radius:
			if pop_count < 16:
				_spawn_projectile_pop(projectile.position, projectile.radius)
				pop_count += 1
			projectile.queue_free()
			cleared += 1
	return cleared

func _spawn_purge_wave(origin: Vector2, radius: float, finisher: bool) -> void:
	var wave := Line2D.new()
	wave.points = _circle_points(radius, 36)
	wave.closed = true
	wave.width = 4.0 if finisher else 2.5
	wave.default_color = Color(0.82, 1.0, 1.0, 0.92) if finisher else Color(0.30, 0.95, 1.0, 0.75)
	wave.antialiased = true
	wave.position = origin
	wave.scale = Vector2.ONE * 0.18
	level.projectile_layer.add_child(wave)
	var tween := wave.create_tween()
	tween.set_parallel(true)
	tween.tween_property(wave, "scale", Vector2.ONE * (1.10 if finisher else 1.0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(wave, "modulate:a", 0.0, 0.22)
	tween.finished.connect(wave.queue_free)

func _spawn_projectile_pop(origin: Vector2, projectile_radius: float) -> void:
	var pop := Line2D.new()
	pop.points = _circle_points(projectile_radius + 5.0, 16)
	pop.closed = true
	pop.width = 2.0
	pop.default_color = Color(0.82, 1.0, 1.0, 0.86)
	pop.antialiased = true
	pop.position = origin
	level.projectile_layer.add_child(pop)
	var tween := pop.create_tween()
	tween.set_parallel(true)
	tween.tween_property(pop, "scale", Vector2.ONE * 2.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(pop, "modulate:a", 0.0, 0.13)
	tween.finished.connect(pop.queue_free)

func _circle_points(radius: float, segment_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_segments := maxi(segment_count, 8)
	for index in range(safe_segments):
		var angle := TAU * float(index) / float(safe_segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _show_target_feedback(origin: Vector2, completed_step: int, bonus: int, cleared: int, chain_complete: bool) -> void:
	level.graze_popup_origin = origin
	level.graze_popup_time = 1.0 if chain_complete else 0.82
	if chain_complete:
		level.graze_popup_label.text = "CHAIN COMPLETE  +%s  //  PURGED %d" % [level._format_score(bonus), cleared]
	elif cleared > 0:
		level.graze_popup_label.text = "CHAIN x%d  +%s  //  PURGED %d" % [completed_step, level._format_score(bonus), cleared]
	else:
		level.graze_popup_label.text = "CHAIN x%d  +%s" % [completed_step, level._format_score(bonus)]
	level.graze_popup_label.modulate.a = 1.0
	level.graze_popup_label.visible = true

func _start_hit_stop() -> void:
	if not is_instance_valid(level) or level.state != "playing":
		return
	var frozen_projectiles: Array[CursorHellProjectile] = []
	for child in level.projectile_layer.get_children():
		var projectile := child as CursorHellProjectile
		if projectile == null or not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
			continue
		projectile.set_physics_process(false)
		frozen_projectiles.append(projectile)
	level.set_process_input(false)
	level.player.set_process(false)
	await get_tree().create_timer(HIT_STOP_TIME, true, false, true).timeout
	if not is_instance_valid(level):
		return
	level.set_process_input(true)
	if level.state != "playing":
		return
	for projectile in frozen_projectiles:
		if is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
			projectile.set_physics_process(true)
	if is_instance_valid(level.player):
		level.player.set_process(true)

func _on_target_expired(target: CursorHellScoreTarget) -> void:
	if active_target != target:
		return
	active_target = null
	if chain_active or target.chain_step > 1:
		_show_chain_lost_feedback(target.position, target.chain_step)
		_reset_chain(true)

func _show_chain_lost_feedback(origin: Vector2, lost_step: int) -> void:
	level.graze_popup_origin = origin
	level.graze_popup_time = 0.70
	level.graze_popup_label.text = "CHAIN LOST  //  %d/%d" % [maxi(lost_step - 1, 1), CHAIN_LENGTH]
	level.graze_popup_label.modulate.a = 1.0
	level.graze_popup_label.visible = true

func _clear_target() -> void:
	if is_instance_valid(active_target):
		active_target.queue_free()
	active_target = null

func _reset_chain(schedule_next: bool) -> void:
	chain_active = false
	chain_step = 0
	if schedule_next and is_instance_valid(level):
		spawn_clock = level.rng.randf_range(min_spawn_delay, max_spawn_delay)

func _reset_runtime() -> void:
	_clear_target()
	_reset_chain(false)
	spawn_clock = first_spawn_delay
