extends "res://scripts/levels/base_level.gd"
class_name CursorHellLevel08

const PylonScene := preload("res://Scenes/Components/Pylon.tscn")
const NeedleScene := preload("res://Scenes/Components/NeedleProjectile.tscn")

const ROUND_TIME := 60.0
const COMPLETION_BONUS := 6000.0
const NEEDLE_RADIUS := 4.5

const PYLON_SLOTS := [
	Vector2(0.22, 0.26),
	Vector2(0.50, 0.22),
	Vector2(0.78, 0.26),
	Vector2(0.22, 0.74),
	Vector2(0.50, 0.78),
	Vector2(0.78, 0.74),
	Vector2(0.31, 0.50),
	Vector2(0.69, 0.50),
	Vector2(0.50, 0.50)
]

@onready var pylon_layer: Node2D = %Pylons

var attack_index := 0
var dead_zone_phase := -1
var last_pylon_slot := -1
var final_axis_horizontal := true

func _reset_round(start_now: bool) -> void:
	attack_index = 0
	dead_zone_phase = -1
	last_pylon_slot = -1
	final_axis_horizontal = true
	if is_instance_valid(pylon_layer):
		for child in pylon_layer.get_children():
			child.queue_free()
	super._reset_round(start_now)

func _input(event: InputEvent) -> void:
	var had_motion := false
	var old_position := Vector2.ZERO
	if (state == "playing" or state == "countdown") and event is InputEventMouseMotion and is_instance_valid(player):
		had_motion = true
		old_position = player.position

	super._input(event)

	if had_motion and state == "playing":
		_swept_dead_zone_collision(old_position, player.position)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == "playing":
		_check_dead_zones()

func _begin_death(reason: String) -> void:
	var was_playing := state == "playing"
	super._begin_death(reason)
	if was_playing and state == "dying":
		_freeze_pylons()

func _win() -> void:
	if state != "playing":
		return
	super._win()
	_freeze_pylons()

func _get_level_number() -> int:
	return 8

func _get_round_time() -> float:
	return ROUND_TIME

func _get_completion_bonus() -> float:
	return COMPLETION_BONUS

func _get_phase() -> int:
	if elapsed < 6.0:
		return 0
	if elapsed < 16.0:
		return 1
	if elapsed < 27.0:
		return 2
	if elapsed < 40.0:
		return 3
	if elapsed < 52.0:
		return 4
	return 5

func _update_level_tutorial() -> void:
	match _get_phase():
		0:
			tutorial_label.text = "DEAD ZONES\nSpace is about to become the hazard."
		1:
			tutorial_label.text = "PYLON INBOUND\nBlue ring = arming. Red field = lethal."
		2:
			if elapsed < 20.0:
				tutorial_label.text = "NEEDLES\nCyan warning = fast precision volley."
			else:
				tutorial_label.text = "USE THE OPEN SPACE\nNeedle volleys punish narrow escape routes."
		3:
			tutorial_label.text = "NEEDLE STORM\nLarge volleys cross the space the pylons leave behind."
		4:
			tutorial_label.text = "THE BOX IS SHRINKING\nDead zones divide the arena. Needle walls close the gaps."
		_:
			tutorial_label.text = "STAY AHEAD\nTwo axes. Almost no recovery. Keep moving."

func _schedule_level_projectile(current_phase: int) -> void:
	if current_phase != dead_zone_phase:
		dead_zone_phase = current_phase
		attack_index = 0
	attack_index += 1

	match current_phase:
		1:
			# Keep one large zone cycling through the teaching phase instead of giving
			# the player a long empty stretch after the first pylon burns out.
			_spawn_pylon(1, 142.0, 5.0, 1.10, 1.00)
		2:
			_schedule_phase_two()
		3:
			_schedule_phase_three()
		4:
			_schedule_phase_four()
		_:
			_schedule_final_phase()

func _schedule_phase_two() -> void:
	# Needles are intentionally much faster than the standard projectile. Even the
	# teaching volley arrives in pairs so their identity is "small and vicious",
	# not simply "a smaller normal bullet".
	if elapsed < 20.0:
		_queue_targeted_needles(2, 600.0, 0.68, 0.030)
		return

	if _live_pylon_count() < 2 and attack_index % 2 == 0:
		_spawn_pylon(2, 146.0, 5.2, 1.05, 0.95)
	var needle_count := 4 if attack_index % 3 == 0 else 3
	_queue_targeted_needles(needle_count, 630.0, 0.60, 0.032)

func _schedule_phase_three() -> void:
	if _live_pylon_count() < 2 and attack_index % 2 == 1:
		_spawn_pylon(2, 152.0, 5.4, 1.00, 0.90)

	_queue_targeted_needles(5, 690.0, 0.52, 0.031)

	# Periodic cross-axis bursts stop one clean sidestep from solving every volley.
	# The second burst warns slightly longer, so it remains readable despite the
	# much higher needle velocity.
	if attack_index % 3 == 0:
		var cross_axis := 0 if final_axis_horizontal else 1
		final_axis_horizontal = not final_axis_horizontal
		_queue_targeted_needles(3, 720.0, 0.64, 0.036, cross_axis)

func _schedule_phase_four() -> void:
	if _live_pylon_count() < 3 and attack_index % 2 == 1:
		_spawn_pylon(3, 158.0, 5.5, 0.94, 0.84)

	var needle_count := 7 if attack_index % 2 == 0 else 6
	_queue_targeted_needles(needle_count, 760.0, 0.44, 0.030)

	# Every other attack gets a second, perpendicular-feeling burst. The two
	# warning timings are offset enough to read as a rapid one-two instead of one
	# giant unreadable flash.
	if attack_index % 2 == 0:
		var secondary_axis := 0 if final_axis_horizontal else 1
		final_axis_horizontal = not final_axis_horizontal
		_queue_targeted_needles(4, 800.0, 0.56, 0.038, secondary_axis)

func _schedule_final_phase() -> void:
	# The finale aggressively restores missing pylons. With the larger radius this
	# keeps the arena partitioned while the needle mechanic finally becomes a true
	# storm: a broad primary volley followed immediately by pressure on the other
	# axis. Small hitboxes are the only mercy these shots receive.
	if _live_pylon_count() < 3:
		_spawn_pylon(3, 165.0, 5.0, 0.82, 0.74)

	var primary_axis := 0 if final_axis_horizontal else 1
	var secondary_axis := 1 if final_axis_horizontal else 0
	final_axis_horizontal = not final_axis_horizontal
	_queue_targeted_needles(8, 850.0, 0.36, 0.028, primary_axis)
	_queue_targeted_needles(6, 900.0, 0.48, 0.032, secondary_axis)

func _queue_targeted_needles(count: int, speed: float, delay: float, spread: float, forced_axis: int = -1) -> void:
	var side: int
	if forced_axis == 0:
		side = 0 if rng.randf() < 0.5 else 1
	elif forced_axis == 1:
		side = 2 if rng.randf() < 0.5 else 3
	else:
		side = rng.randi_range(0, 3)

	var center := _target_lane_for_side(side, 0.025)
	var center_index := float(count - 1) * 0.5
	for index in range(count):
		var lane := clampf(center + (float(index) - center_index) * spread, 0.07, 0.93)
		queue_projectile_warning(side, lane, speed, NEEDLE_RADIUS, delay)
		var warning_index := warnings.size() - 1
		if warning_index >= 0:
			var warning: Dictionary = warnings[warning_index]
			warning["projectile_kind"] = "needle"
			warning["warning_kind"] = "needle"

func _release_warning(warning: Dictionary) -> void:
	if str(warning.get("projectile_kind", "")) != "needle":
		super._release_warning(warning)
		return

	var side := int(warning["side"])
	var lane := float(warning["lane"])
	var speed := float(warning["speed"])
	var radius := float(warning["radius"])
	var padding := 30.0
	var spawn_position := Vector2.ZERO
	var velocity := Vector2.ZERO

	match side:
		0:
			spawn_position = Vector2(ARENA.position.x - padding, ARENA.position.y + ARENA.size.y * lane)
			velocity = Vector2(speed, 0.0)
		1:
			spawn_position = Vector2(ARENA.end.x + padding, ARENA.position.y + ARENA.size.y * lane)
			velocity = Vector2(-speed, 0.0)
		2:
			spawn_position = Vector2(ARENA.position.x + ARENA.size.x * lane, ARENA.position.y - padding)
			velocity = Vector2(0.0, speed)
		_:
			spawn_position = Vector2(ARENA.position.x + ARENA.size.x * lane, ARENA.end.y + padding)
			velocity = Vector2(0.0, -speed)

	var bullet := NeedleScene.instantiate() as CursorHellProjectile
	if bullet == null:
		push_error("Cursor Hell: NeedleProjectile.tscn must use CursorHellProjectile.")
		return
	bullet.position = spawn_position
	bullet.velocity = velocity
	bullet.radius = radius
	bullet.set_meta("projectile_kind", "needle")
	projectile_layer.add_child(bullet)
	SfxScript.play_projectile(self)

func _spawn_pylon(max_active: int, radius: float, active_duration: float, travel_duration: float, arm_duration: float) -> void:
	if _live_pylon_count() >= max_active:
		return

	var selection := _choose_pylon_target(radius)
	if selection.is_empty():
		return

	var slot_index := int(selection["slot"])
	var target: Vector2 = selection["position"]
	var pylon := PylonScene.instantiate() as CursorHellDeadZonePylon
	if pylon == null:
		push_error("Cursor Hell: Pylon.tscn must use CursorHellDeadZonePylon.")
		return

	pylon.position = _pylon_spawn_from_edge(target)
	pylon.target_position = target
	pylon.zone_radius = radius
	pylon.active_time = active_duration
	pylon.travel_time = travel_duration
	pylon.arm_time = arm_duration
	pylon_layer.add_child(pylon)
	last_pylon_slot = slot_index

func _choose_pylon_target(radius: float) -> Dictionary:
	var candidates: Array[int] = []
	for index in range(PYLON_SLOTS.size()):
		if index != last_pylon_slot:
			candidates.append(index)
	candidates.shuffle()

	for slot_index in candidates:
		var target := ARENA.position + Vector2(
			ARENA.size.x * PYLON_SLOTS[slot_index].x,
			ARENA.size.y * PYLON_SLOTS[slot_index].y
		)
		# Pylons still never materialize on top of the player, but the safety buffer
		# is intentionally tighter now. Travel + arming time is the warning window.
		if target.distance_to(player.position) < radius + 58.0:
			continue
		if not _pylon_target_has_space(target, radius):
			continue
		return {"slot": slot_index, "position": target}

	# If every authored slot would create an unfair placement, skip this pylon
	# rather than forcing an unavoidable dead zone.
	return {}

func _pylon_target_has_space(target: Vector2, radius: float) -> bool:
	for child in pylon_layer.get_children():
		var pylon := child as CursorHellDeadZonePylon
		if pylon == null or not is_instance_valid(pylon) or pylon.is_queued_for_deletion():
			continue
		# Mild overlap is deliberate. Large circles should be able to join into
		# temporary walls, but their centers cannot stack into one unreadable blob.
		var minimum_spacing := maxf(radius, pylon.zone_radius) * 1.35 + 34.0
		if target.distance_to(pylon.target_position) < minimum_spacing:
			return false
	return true

func _pylon_spawn_from_edge(target: Vector2) -> Vector2:
	var side := rng.randi_range(0, 3)
	var padding := 34.0
	match side:
		0:
			return Vector2(ARENA.position.x - padding, target.y)
		1:
			return Vector2(ARENA.end.x + padding, target.y)
		2:
			return Vector2(target.x, ARENA.position.y - padding)
		_:
			return Vector2(target.x, ARENA.end.y + padding)

func _live_pylon_count() -> int:
	var count := 0
	for child in pylon_layer.get_children():
		var pylon := child as CursorHellDeadZonePylon
		if pylon != null and is_instance_valid(pylon) and not pylon.is_queued_for_deletion():
			count += 1
	return count

func _check_dead_zones() -> void:
	for child in pylon_layer.get_children():
		var pylon := child as CursorHellDeadZonePylon
		if pylon == null or not is_instance_valid(pylon) or pylon.is_queued_for_deletion() or not pylon.is_lethal():
			continue
		if player.position.distance_to(pylon.position) <= pylon.zone_radius + PLAYER_RADIUS:
			_begin_death("Dead zone contact")
			return

func _swept_dead_zone_collision(start: Vector2, finish: Vector2) -> void:
	for child in pylon_layer.get_children():
		var pylon := child as CursorHellDeadZonePylon
		if pylon == null or not is_instance_valid(pylon) or pylon.is_queued_for_deletion() or not pylon.is_lethal():
			continue
		var closest := _closest_point_on_segment(pylon.position, start, finish)
		if closest.distance_to(pylon.position) <= pylon.zone_radius + PLAYER_RADIUS:
			player.position = closest
			_begin_death("Dead zone contact")
			return

func _freeze_pylons() -> void:
	for child in pylon_layer.get_children():
		if is_instance_valid(child):
			child.set_physics_process(false)

func _target_lane_for_side(side: int, jitter: float) -> float:
	var lane: float
	if side == 0 or side == 1:
		lane = (player.position.y - ARENA.position.y) / ARENA.size.y
	else:
		lane = (player.position.x - ARENA.position.x) / ARENA.size.x
	lane += rng.randf_range(-jitter, jitter)
	return clampf(lane, 0.08, 0.92)

func _get_spawn_interval(current_phase: int) -> float:
	match current_phase:
		1:
			return 2.80
		2:
			return rng.randf_range(1.20, 1.38)
		3:
			return rng.randf_range(0.98, 1.14)
		4:
			return rng.randf_range(0.80, 0.94)
		_:
			return rng.randf_range(0.62, 0.74)

func _graze_enabled_for_phase(current_phase: int) -> bool:
	return current_phase >= 2

func _get_intro_title() -> String:
	return "DEAD ZONES"

func _get_intro_subtitle() -> String:
	return "LEVEL 8 — TERRITORY"

func _get_intro_body() -> String:
	return "The floor is no longer neutral.\n\nPylons enter the arena, arm, and turn large areas lethal.\nNeedles use their own cyan warning, arrive in dense volleys, and move far faster than standard projectiles.\nRead the floor, protect an exit route, and survive for 60 seconds.\n\nCLICK TO BEGIN"

func _get_pause_subtitle() -> String:
	return "LEVEL 8 — DEAD ZONES"

func _get_countdown_tutorial_text() -> String:
	return "GET READY\nBlue arms. Red kills. Cyan means needle."

func _get_countdown_subtitle() -> String:
	return "DEAD ZONES"

func _get_death_title() -> String:
	return "RUN ENDED"

func _get_death_subtitle() -> String:
	return "LEVEL 8 — SPACE DENIED"

func _get_death_body(reason: String, run_time: float, final_score: int, best_score: int) -> String:
	return "%s\n\nTIME   %s / 1:00\nSCORE  %s\nBEST   %s\n\nCLICK OR PRESS R TO RETRY" % [reason.to_upper(), _format_time(run_time), _format_score(final_score), _format_score(best_score)]

func _get_win_title() -> String:
	return "LEVEL COMPLETE"

func _get_win_subtitle() -> String:
	return "DEAD ZONES CLEARED"

func _get_win_tutorial_text() -> String:
	return "LEVEL COMPLETE\nDEAD ZONES CLEARED"

func _get_win_body(final_score: int, best_score: int) -> String:
	return "60 SECONDS SURVIVED\n\nCOMPLETION BONUS   +6,000\nFINAL SCORE        %s\nBEST SCORE         %s\n\nPylons, lethal territory and needle pressure survived.\n\n%s" % [_format_score(final_score), _format_score(best_score), _get_win_action_text()]
