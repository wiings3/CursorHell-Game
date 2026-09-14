extends "res://scripts/levels/standard_dodge_level.gd"
class_name CursorHellEndlessMode

const PREPARE_TIME := 5.0
const NORMAL_PHASE_DURATION := 25.0
const NORMAL_PHASES_PER_BOSS := 5
const BOSS_PHASE_DURATION := 30.0
const POST_BOSS_BREATHER := 5.0
const CYCLE_DURATION := NORMAL_PHASE_DURATION * NORMAL_PHASES_PER_BOSS + BOSS_PHASE_DURATION + POST_BOSS_BREATHER
const EFFECTIVE_ROUND_TIME := 315360000.0

var last_segment_key := ""
var last_segment_kind := ""
var last_segment_number := 0
var corridor_step := 0

@onready var endless_hud: Control = hud.get_node("ScreenUI/EndlessPhaseHUD") as Control
@onready var phase_label: Label = hud.get_node("ScreenUI/EndlessPhaseHUD/PhaseLabel") as Label
@onready var tier_label: Label = hud.get_node("ScreenUI/EndlessPhaseHUD/TierLabel") as Label
@onready var progress_track: Control = hud.get_node("ScreenUI/EndlessPhaseHUD/ProgressTrack") as Control
@onready var progress_fill: ColorRect = hud.get_node("ScreenUI/EndlessPhaseHUD/ProgressTrack/ProgressFill") as ColorRect

func _ready() -> void:
	super._ready()
	hud.level_number_label.text = "ENDLESS"
	hud.level_name_label.text = "SURVIVAL PROTOCOL"
	hud.boss_tag_label.visible = false
	endless_hud.visible = true
	_sync_endless_hud()

func _reset_round(start_now: bool) -> void:
	last_segment_key = ""
	last_segment_kind = ""
	last_segment_number = 0
	corridor_step = 0
	super._reset_round(start_now)
	if is_instance_valid(endless_hud):
		endless_hud.visible = true
	_remember_segment(_timeline_at(elapsed))
	_sync_endless_hud()

func _start_countdown() -> void:
	# Endless begins at 0:00. Its first five seconds are the prepare window, so it
	# does not stack the campaign's 3-2-1 countdown on top of that downtime.
	state = "playing"
	countdown_left = 0.0
	countdown_step = -1
	_hide_message_panel()
	_capture_mouse()
	countdown_label.visible = false
	countdown_subtitle.visible = false
	_update_level_tutorial()
	_sync_endless_hud()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == "playing":
		_handle_segment_change()
		_sync_endless_hud()

func _get_level_number() -> int:
	return 0

func _get_round_time() -> float:
	# BaseLevel's reusable runtime expects a duration. Endless overrides _win(),
	# displays elapsed time instead, and therefore has no reachable clear state.
	return EFFECTIVE_ROUND_TIME

func _win() -> void:
	# Endless Mode has no victory condition.
	pass

func _get_phase() -> int:
	var info := _timeline_at(elapsed)
	match str(info["kind"]):
		"normal":
			return int(info["phase"])
		"boss":
			return 1000 + int(info["boss"])
		_:
			return 0

func _schedule_level_projectile(_current_phase: int) -> void:
	var info := _timeline_at(elapsed)
	if str(info["kind"]) == "boss":
		_schedule_boss_pattern(info)
	elif str(info["kind"]) == "normal":
		_schedule_normal_pattern(info)

func _get_spawn_interval(_current_phase: int) -> float:
	var info := _timeline_at(elapsed)
	if str(info["kind"]) == "boss":
		var boss := int(info["boss"])
		return maxf(0.88, 1.48 - float(boss - 1) * 0.055)
	if str(info["kind"]) != "normal":
		return 999.0

	var phase := int(info["phase"])
	var tier := int(info["tier"])
	var interval := 1.72 - float(phase - 1) * 0.045 - float(tier - 1) * 0.04
	if _current_mutator(info) == "DOUBLE SWEEP":
		interval += 0.16
	return maxf(0.58, interval)

func _graze_enabled_for_phase(current_phase: int) -> bool:
	return current_phase > 0

func _update_level_tutorial() -> void:
	var info := _timeline_at(elapsed)
	match str(info["kind"]):
		"prepare":
			tutorial_label.text = "PREPARE\nThreat sequence begins at 0:05."
		"normal":
			var mutator := _current_mutator(info)
			if mutator.is_empty():
				tutorial_label.text = "PHASE %02d  //  TIER %d\nSurvive. Graze for score." % [int(info["phase"]), int(info["tier"])]
			else:
				tutorial_label.text = "PHASE %02d  //  %s\nAdapt to the active modifier." % [int(info["phase"]), mutator]
		"boss":
			tutorial_label.text = "BOSS PHASE %d\nSurvive the protocol shift." % int(info["boss"])
		"breather":
			tutorial_label.text = "BOSS CLEARED\n5 second recovery window."

func _update_ui() -> void:
	super._update_ui()
	if timer_label != null:
		timer_label.text = _format_endless_time(elapsed)
	_sync_endless_hud()

func _schedule_normal_pattern(info: Dictionary) -> void:
	var phase := int(info["phase"])
	var tier := int(info["tier"])
	var speed := _normal_speed(phase, tier)
	var radius := minf(9.0, 7.0 + float(tier - 1) * 0.25)
	var delay := _warning_delay(phase, tier)
	var mutator := _current_mutator(info)
	var roll := rng.randf()

	if mutator == "TIGHT WARNING":
		delay = maxf(0.50, delay * 0.82)
	elif mutator == "OPPOSITE FIRE":
		_queue_opposite_pair(speed, radius, delay)
		return
	elif mutator == "DOUBLE SWEEP":
		_queue_double_sweep(speed, radius, delay)
		return
	elif mutator == "SAFE CORRIDOR":
		_queue_safe_corridor(speed * 0.92, radius, delay)
		return

	var complexity := phase + tier * 2
	if complexity >= 12 and roll < 0.16:
		_queue_cardinal_cross(speed * 0.94, radius, delay)
	elif complexity >= 8 and roll < 0.34:
		_queue_wall_gap(rng.randi_range(0, 3), speed * 0.92, radius, delay, rng.randf_range(0.30, 0.70))
	elif complexity >= 5 and roll < 0.56:
		_queue_opposite_pair(speed, radius, delay)
	elif complexity >= 3 and roll < 0.74:
		_queue_same_side_double(speed, radius, delay)
	else:
		_queue_single(speed, radius, delay)

func _schedule_boss_pattern(info: Dictionary) -> void:
	var boss := int(info["boss"])
	var tier := int(info["tier"])
	var phase_elapsed := float(info["phase_elapsed"])
	var pattern_index := int(floor(phase_elapsed / 6.0)) % 5
	var speed := minf(292.0, 178.0 + float(boss - 1) * 8.0 + float(tier - 1) * 3.0)
	var radius := minf(9.5, 7.5 + float(boss - 1) * 0.18)
	var delay := maxf(0.56, 0.96 - float(boss - 1) * 0.025)

	match pattern_index:
		0:
			_queue_opposite_pair(speed, radius, delay)
		1:
			_queue_cardinal_cross(speed * 0.94, radius, delay)
		2:
			_queue_wall_gap((boss + corridor_step) % 4, speed * 0.90, radius, delay, rng.randf_range(0.30, 0.70))
			corridor_step += 1
		3:
			_queue_safe_corridor(speed * 0.88, radius, delay)
		_:
			_queue_double_sweep(speed, radius, delay)

func _queue_single(speed: float, radius: float, delay: float) -> void:
	var side := rng.randi_range(0, 3)
	var lane := rng.randf_range(0.11, 0.89)
	for _attempt in range(3):
		if absf(lane - float(last_lane_by_side[side])) >= 0.08:
			break
		lane = rng.randf_range(0.11, 0.89)
	last_lane_by_side[side] = lane
	queue_projectile_warning(side, lane, speed, radius, delay)

func _queue_opposite_pair(speed: float, radius: float, delay: float) -> void:
	var side := rng.randi_range(0, 3)
	var opposite := 1 - side if side < 2 else 5 - side
	var lane := rng.randf_range(0.16, 0.84)
	queue_projectile_warning(side, lane, speed, radius, delay)
	queue_projectile_warning(opposite, clampf(1.0 - lane + rng.randf_range(-0.08, 0.08), 0.12, 0.88), speed * 0.96, radius, delay + 0.08)

func _queue_same_side_double(speed: float, radius: float, delay: float) -> void:
	var side := rng.randi_range(0, 3)
	var center := rng.randf_range(0.28, 0.72)
	var gap := rng.randf_range(0.12, 0.18)
	queue_projectile_warning(side, clampf(center - gap, 0.10, 0.90), speed, radius, delay)
	queue_projectile_warning(side, clampf(center + gap, 0.10, 0.90), speed * 1.03, radius, delay + 0.06)

func _queue_cardinal_cross(speed: float, radius: float, delay: float) -> void:
	var lane := rng.randf_range(0.28, 0.72)
	for side in range(4):
		var side_lane := lane if side % 2 == 0 else clampf(1.0 - lane, 0.18, 0.82)
		queue_projectile_warning(side, side_lane, speed, radius, delay + float(side) * 0.035)

func _queue_wall_gap(side: int, speed: float, radius: float, delay: float, gap_center: float) -> void:
	var lanes := [0.14, 0.28, 0.42, 0.58, 0.72, 0.86]
	for lane_value in lanes:
		var lane := float(lane_value)
		if absf(lane - gap_center) < 0.15:
			continue
		queue_projectile_warning(side, lane, speed, radius, delay)

func _queue_safe_corridor(speed: float, radius: float, delay: float) -> void:
	var gap_centers := [0.28, 0.40, 0.52, 0.64, 0.72]
	var gap := float(gap_centers[corridor_step % gap_centers.size()])
	corridor_step += 1
	var horizontal := corridor_step % 2 == 0
	if horizontal:
		_queue_wall_gap(0, speed, radius, delay, gap)
		_queue_wall_gap(1, speed * 0.97, radius, delay + 0.08, gap)
	else:
		_queue_wall_gap(2, speed, radius, delay, gap)
		_queue_wall_gap(3, speed * 0.97, radius, delay + 0.08, gap)

func _queue_double_sweep(speed: float, radius: float, delay: float) -> void:
	var horizontal := rng.randf() < 0.5
	var first_side := 0 if horizontal else 2
	var second_side := 1 if horizontal else 3
	var lane := rng.randf_range(0.20, 0.80)
	var offset := 0.16
	queue_projectile_warning(first_side, clampf(lane - offset, 0.10, 0.90), speed, radius, delay)
	queue_projectile_warning(first_side, clampf(lane + offset, 0.10, 0.90), speed * 1.02, radius, delay + 0.08)
	queue_projectile_warning(second_side, clampf(1.0 - lane - offset, 0.10, 0.90), speed * 0.96, radius, delay + 0.16)
	queue_projectile_warning(second_side, clampf(1.0 - lane + offset, 0.10, 0.90), speed, radius, delay + 0.24)

func _normal_speed(phase: int, tier: int) -> float:
	var phase_gain := minf(float(phase - 1) * 4.0, 96.0)
	var tier_gain := minf(float(tier - 1) * 8.0, 48.0)
	return minf(300.0, 148.0 + phase_gain + tier_gain)

func _warning_delay(phase: int, tier: int) -> float:
	var delay := 1.02 - float(phase - 1) * 0.015 - float(tier - 1) * 0.025
	return maxf(0.54, delay)

func _current_mutator(info: Dictionary) -> String:
	var tier := int(info["tier"])
	if tier < 4 or str(info["kind"]) != "normal":
		return ""
	var phase := int(info["phase"])
	var mutators := ["TIGHT WARNING", "OPPOSITE FIRE", "DOUBLE SWEEP", "SAFE CORRIDOR"]
	return str(mutators[(phase - 1) % mutators.size()])

func _handle_segment_change() -> void:
	var info := _timeline_at(elapsed)
	var key := str(info["key"])
	if key == last_segment_key:
		return

	if last_segment_kind == "normal":
		_award_phase_clear(last_segment_number)
	elif last_segment_kind == "boss" and str(info["kind"]) == "breather":
		_award_boss_clear(last_segment_number)
		_clear_all_hazards()

	if str(info["kind"]) == "breather":
		_clear_all_hazards()

	_remember_segment(info)
	_update_level_tutorial()

func _award_phase_clear(phase_number: int) -> void:
	if phase_number <= 0:
		return
	var bonus := 750 + phase_number * 75
	score += bonus
	score_punch = 1.0
	run_stats.update_live(elapsed, int(score))

func _award_boss_clear(boss_number: int) -> void:
	if boss_number <= 0:
		return
	var bonus := 4000 + boss_number * 1000
	score += bonus
	score_punch = 1.0
	run_stats.update_live(elapsed, int(score))

func _clear_all_hazards() -> void:
	warnings.clear()
	for child in projectile_layer.get_children():
		if is_instance_valid(child):
			child.queue_free()
	if is_instance_valid(warning_layer):
		warning_layer._sync_warning_markers()

func _remember_segment(info: Dictionary) -> void:
	last_segment_key = str(info["key"])
	last_segment_kind = str(info["kind"])
	if last_segment_kind == "normal":
		last_segment_number = int(info["phase"])
	elif last_segment_kind == "boss":
		last_segment_number = int(info["boss"])
	else:
		last_segment_number = 0

func _sync_endless_hud() -> void:
	if not is_instance_valid(endless_hud) or not is_instance_valid(progress_track) or not is_instance_valid(progress_fill):
		return
	endless_hud.visible = true
	var info := _timeline_at(elapsed)
	var kind := str(info["kind"])
	var progress := clampf(float(info["progress"]), 0.0, 1.0)
	progress_fill.size.x = progress_track.size.x * progress

	match kind:
		"prepare":
			phase_label.text = "PREPARE"
			tier_label.text = "ENDLESS  //  0:05"
			progress_fill.color = Color(0.72, 0.67, 0.56, 0.92)
		"normal":
			phase_label.text = "PHASE %02d" % int(info["phase"])
			var mutator := _current_mutator(info)
			tier_label.text = "TIER %d" % int(info["tier"]) if mutator.is_empty() else "TIER %d  //  %s" % [int(info["tier"]), mutator]
			progress_fill.color = Color(1.0, 0.61, 0.16, 0.92)
		"boss":
			phase_label.text = "BOSS PHASE %d" % int(info["boss"])
			tier_label.text = "THREAT TIER %d" % int(info["tier"])
			progress_fill.color = Color(1.0, 0.25, 0.12, 0.95)
		"breather":
			phase_label.text = "BOSS CLEARED"
			tier_label.text = "NEXT TIER IN %d" % maxi(0, int(ceil(float(info["duration"]) - float(info["phase_elapsed"]))))
			progress_fill.color = Color(0.72, 0.82, 0.58, 0.90)

func _timeline_at(run_time: float) -> Dictionary:
	var safe_time := maxf(0.0, run_time)
	if safe_time < PREPARE_TIME:
		return {
			"key": "prepare",
			"kind": "prepare",
			"phase": 0,
			"boss": 0,
			"tier": 1,
			"bosses_cleared": 0,
			"phase_elapsed": safe_time,
			"duration": PREPARE_TIME,
			"progress": safe_time / PREPARE_TIME
		}

	var active_time := safe_time - PREPARE_TIME
	var cycle := int(floor(active_time / CYCLE_DURATION))
	var cycle_time := fmod(active_time, CYCLE_DURATION)
	var normal_block := NORMAL_PHASE_DURATION * NORMAL_PHASES_PER_BOSS
	var completed_before_cycle := cycle

	if cycle_time < normal_block:
		var slot := int(floor(cycle_time / NORMAL_PHASE_DURATION))
		var phase_number := cycle * NORMAL_PHASES_PER_BOSS + slot + 1
		var phase_elapsed := fmod(cycle_time, NORMAL_PHASE_DURATION)
		return {
			"key": "normal:%d" % phase_number,
			"kind": "normal",
			"phase": phase_number,
			"boss": cycle + 1,
			"tier": completed_before_cycle + 1,
			"bosses_cleared": completed_before_cycle,
			"phase_elapsed": phase_elapsed,
			"duration": NORMAL_PHASE_DURATION,
			"progress": phase_elapsed / NORMAL_PHASE_DURATION
		}

	cycle_time -= normal_block
	if cycle_time < BOSS_PHASE_DURATION:
		var boss_number := cycle + 1
		return {
			"key": "boss:%d" % boss_number,
			"kind": "boss",
			"phase": cycle * NORMAL_PHASES_PER_BOSS + NORMAL_PHASES_PER_BOSS,
			"boss": boss_number,
			"tier": completed_before_cycle + 1,
			"bosses_cleared": completed_before_cycle,
			"phase_elapsed": cycle_time,
			"duration": BOSS_PHASE_DURATION,
			"progress": cycle_time / BOSS_PHASE_DURATION
		}

	cycle_time -= BOSS_PHASE_DURATION
	var cleared_boss := cycle + 1
	return {
		"key": "breather:%d" % cleared_boss,
		"kind": "breather",
		"phase": cycle * NORMAL_PHASES_PER_BOSS + NORMAL_PHASES_PER_BOSS,
		"boss": cleared_boss,
		"tier": cleared_boss + 1,
		"bosses_cleared": cleared_boss,
		"phase_elapsed": cycle_time,
		"duration": POST_BOSS_BREATHER,
		"progress": cycle_time / POST_BOSS_BREATHER
	}

func get_endless_summary() -> Dictionary:
	var info := _timeline_at(elapsed)
	var phase_reached := int(info["phase"])
	var bosses_cleared := int(info["bosses_cleared"])
	var points := phase_reached * 7 + bosses_cleared * 18
	points += mini(run_stats.max_graze_combo * 2, 16)
	points += mini(int(score / 2500.0), 25)
	var rank := "F"
	if points >= 120:
		rank = "S+"
	elif points >= 90:
		rank = "S"
	elif points >= 70:
		rank = "A"
	elif points >= 50:
		rank = "B"
	elif points >= 35:
		rank = "C"
	elif points >= 20:
		rank = "D"
	return {
		"phase": phase_reached,
		"bosses": bosses_cleared,
		"tier": int(info["tier"]),
		"rank": rank,
		"points": points,
		"time": elapsed,
		"score": int(score),
		"max_combo": run_stats.max_graze_combo
	}

func _get_intro_title() -> String:
	return "SURVIVAL PROTOCOL"

func _get_intro_subtitle() -> String:
	return "ENDLESS MODE  //  NO FINISH LINE"

func _get_intro_body() -> String:
	return "Survive as long as possible.\n\n5 seconds of preparation.\n25-second phases increase pressure without removing readability.\nEvery 5 phases triggers a boss protocol.\nBoss clears grant a 5-second breather and advance the threat tier.\n\nGraze aggressively to push your score."

func _get_pause_subtitle() -> String:
	return "ENDLESS MODE"

func _get_death_title() -> String:
	return "ENDLESS RUN ENDED"

func _get_death_subtitle() -> String:
	return "SURVIVAL PROTOCOL TERMINATED"

func _format_endless_time(seconds: float) -> String:
	var whole := maxi(0, int(floor(seconds)))
	return "%d:%02d" % [int(whole / 60), whole % 60]
