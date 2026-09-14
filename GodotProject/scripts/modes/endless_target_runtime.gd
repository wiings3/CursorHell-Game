extends Node
class_name CursorHellEndlessTargetRuntime

const ScoreTargetScene := preload("res://Scenes/Components/ScoreTarget.tscn")
const ARENA := CursorHellMachineShell.LOGICAL_ARENA

@export var first_spawn_delay: float = 7.0
@export var min_spawn_delay: float = 8.0
@export var max_spawn_delay: float = 13.0
@export var projectile_clear_bonus: int = 250
@export var spawn_edge_margin: float = 105.0
@export var min_player_distance: float = 150.0

var level: CursorHellEndlessMode
var active_target: CursorHellScoreTarget
var spawn_clock := 7.0
var last_elapsed := 0.0

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

	# A retry resets Endless in-place, so reset this independent runtime whenever
	# the parent's elapsed clock jumps backward.
	if level.elapsed + 0.01 < last_elapsed:
		_reset_runtime()
	last_elapsed = level.elapsed

	if level.state != "playing":
		_clear_target()
		return

	var info: Dictionary = level._timeline_at(level.elapsed)
	var kind := str(info.get("kind", ""))
	if kind == "prepare" or kind == "breather":
		_clear_target()
		return

	if is_instance_valid(active_target):
		return

	spawn_clock -= delta
	if spawn_clock <= 0.0:
		_spawn_target()

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

	# The player node is the cursor while the OS mouse is captured. A target click
	# therefore means clicking while the player cursor is physically over it.
	if active_target.contains_point(level.player.global_position):
		_activate_target()
		get_viewport().set_input_as_handled()

func _spawn_target() -> void:
	var target := ScoreTargetScene.instantiate() as CursorHellScoreTarget
	if target == null:
		push_error("Cursor Hell: ScoreTarget.tscn must use CursorHellScoreTarget.")
		return

	level.projectile_layer.add_child(target)
	target.position = _choose_spawn_position()
	target.expired.connect(_on_target_expired)
	active_target = target
	spawn_clock = level.rng.randf_range(min_spawn_delay, max_spawn_delay)

func _choose_spawn_position() -> Vector2:
	var left := ARENA.position.x + spawn_edge_margin
	var right := ARENA.end.x - spawn_edge_margin
	var top := ARENA.position.y + spawn_edge_margin
	var bottom := ARENA.end.y - spawn_edge_margin
	var candidate := ARENA.get_center()

	for _attempt in range(10):
		candidate = Vector2(
			level.rng.randf_range(left, right),
			level.rng.randf_range(top, bottom)
		)
		if candidate.distance_to(level.player.position) >= min_player_distance:
			break
	return candidate

func _activate_target() -> void:
	if not is_instance_valid(active_target):
		return

	var target := active_target
	active_target = null
	var cleared := _purge_projectiles(target.global_position, target.purge_radius)
	var bonus := target.score_bonus + cleared * projectile_clear_bonus

	level.score += bonus
	level.score_punch = 1.0
	level.run_stats.update_live(level.elapsed, int(level.score))
	_show_target_feedback(target.position, bonus, cleared)
	target.consume()

func _purge_projectiles(center: Vector2, radius: float) -> int:
	var cleared := 0
	for child in level.projectile_layer.get_children():
		var projectile := child as CursorHellProjectile
		if projectile == null or not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
			continue
		if projectile.global_position.distance_to(center) <= radius + projectile.radius:
			projectile.queue_free()
			cleared += 1
	return cleared

func _show_target_feedback(origin: Vector2, bonus: int, cleared: int) -> void:
	level.graze_popup_origin = origin
	level.graze_popup_time = 0.85
	if cleared > 0:
		level.graze_popup_label.text = "TARGET  +%s  //  PURGED %d" % [level._format_score(bonus), cleared]
	else:
		level.graze_popup_label.text = "TARGET  +%s" % level._format_score(bonus)
	level.graze_popup_label.modulate.a = 1.0
	level.graze_popup_label.visible = true

func _on_target_expired(target: CursorHellScoreTarget) -> void:
	if active_target == target:
		active_target = null

func _clear_target() -> void:
	if is_instance_valid(active_target):
		active_target.queue_free()
	active_target = null

func _reset_runtime() -> void:
	_clear_target()
	spawn_clock = first_spawn_delay
