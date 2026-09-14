extends "res://scripts/levels/standard_dodge_level.gd"
class_name CursorHellEndlessMode

const PREPARE_TIME := 5.0
const NORMAL_PHASE_DURATION := 12.0
const NORMAL_PHASES_PER_BOSS := 5
const BOSS_PHASE_DURATION := 30.0
const POST_BOSS_BREATHER := 5.0
const CYCLE_DURATION := NORMAL_PHASE_DURATION * NORMAL_PHASES_PER_BOSS + BOSS_PHASE_DURATION + POST_BOSS_BREATHER
const EFFECTIVE_ROUND_TIME := 315360000.0

const TIER_1_PATTERNS := ["ALTERNATING", "OPPOSITION", "SPLIT LANE", "SWEEP"]
const TIER_2_PATTERNS := ["OPPOSITION", "SPLIT LANE", "SWEEP", "CORRIDOR", "CROSS FIRE"]
const TIER_3_PATTERNS := ["SWEEP", "CORRIDOR", "CROSS FIRE", "DOUBLE SWEEP", "MIXED PRESSURE"]
const TIER_4_PATTERNS := ["CORRIDOR", "CROSS FIRE", "DOUBLE SWEEP", "SAFE CORRIDOR", "TIGHT WARNING", "MIXED PRESSURE"]

var last_segment_key := ""
var last_segment_kind := ""
var last_segment_number := 0
var corridor_step := 0
var pattern_step := 0
var active_pattern_key := ""
var active_phase_pattern := ""
var previous_phase_pattern := ""

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
	pattern_step = 0
	active_pattern_key = ""
	active_phase_pattern = ""
	previous_phase_pattern = ""
	super._reset_round(start_now)
	if is_instance_valid(endless_hud):
		endless_hud.visible = true
	_remember_segment(_timeline_at(elapsed))
	_sync_endless_hud()

func _start_countdown() -> void:
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
	return EFFECTIVE_ROUND_TIME

func _win() -> void:
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
		return maxf(0.78, 1.26 - float(boss - 1) * 0.045)
	if str(info["kind"]) != "normal":
		return 999.0

	var phase := int(info["phase"])
	var tier := int(info["tier"])
	var interval := 1.30 - float(phase - 1) * 0.025 - float(tier - 1) * 0.035
	var pattern := _pattern_for_info(info)
	if pattern == "DOUBLE SWEEP" or pattern == "SAFE CORRIDOR":
		interval += 0.16
	elif pattern == "CORRIDOR" or pattern == "CROSS FIRE":
		interval += 0.08
	return maxf(0.55, interval)

func _graze_enabled_for_phase(current_phase: int) -> bool:
	return current_phase > 0

func _update_level_tutorial() -> void:
	var info := _timeline_at(elapsed)
	match str(info["kind"]):
		"prepare":
			tutorial_label.text = "PREPARE\nThreat sequence begins at 0:05."
		"normal":
			var pattern := _pattern_for_info(info)
			tutorial_label.text = "PHASE %02d  //  %s\nSurvive. Graze for score." % [int(info["phase"]), pattern]
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
	var pattern := _pattern_for_info(info)

	if pattern == "TIGHT WARNING":
		delay = maxf(0.48, delay * 0.78)
		if pattern_step % 2 == 0:
			_queue_opposite_pair(speed, radius, delay)
		else:
			_queue_same_side_double(speed, radius, delay)
	elif pattern == "ALTERNATING":
		_queue_alternating(speed, radius, delay)
	elif pattern == "OPPOSITION":
		_queue_opposite_pair(speed, radius, delay)
	elif pattern == "SPLIT LANE":
		_queue_same_side_double(speed, radius, delay)
	elif pattern == "SWEEP":
		_queue_sweep(speed, radius, delay)
	elif pattern == "CORRIDOR":
		_queue_wall_gap((pattern_step + tier) % 4, speed * 0.94, radius, delay, _stepped_gap())
	elif pattern == "CROSS FIRE":
		_queue_cross_fire(speed, radius, delay)
	elif pattern == "DOUBLE SWEEP":
		_queue_double_sweep(speed, radius, delay)
	elif pattern == "SAFE CORRIDOR":
		_queue_safe_corridor(speed * 0.92, radius, delay)
	elif pattern == "MIXED PRESSURE":
		match pattern_step % 3:
			0:
				_queue_opposite_pair(speed, radius, delay)
			1:
				_queue_same_side_double(speed, radius, delay)
			_:
				_queue_cross_fire(speed * 0.95, radius, delay)
	else:
		_queue_single(speed, radius, delay)

	pattern_step += 1

func _schedule_boss_pattern(info: Dictionary) -> void:
	var boss := int(info["boss"])
	var tier := int(info["tier"])
	var phase_elapsed := float(info["phase_elapsed"])
	var pattern_index := int(floor(phase_elapsed / 6.0)) % 5
	var speed := minf(300.0, 188.0 + float(boss - 1) * 8.0 + float(tier - 1) * 3.0)
	var radius := minf(9.5, 7.5 + float(boss - 1) * 0.18)
	var delay := maxf(0.54, 0.92 - float(boss - 1) * 0.025)

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

func _pattern_for_info(info: Dictionary) -> String:
	if str(info["kind"]) != "normal":
		return ""
	var key := str(info["key"])
	if active_pattern_key == key and not active_phase_pattern.is_empty():
		return active_phase_pattern

	var pool := _pattern_pool_for_tier(int(info["tier"]))
	var candidates := pool.duplicate()
	if candidates.size() > 1 and not previous_phase_pattern.is_empty():
		candidates.erase(previous_phase_pattern)
	active_phase_pattern = str(candidates[rng.randi_range(0, candidates.size() - 1)])
	active_pattern_key = key
	previous_phase_pattern = active_phase_pattern
	pattern_step = 0
	return active_phase_pattern

func _pattern_pool_for_tier(tier: int) -> Array:
	if tier <= 1:
		return TIER_1_PATTERNS
	if tier == 2:
		return TIER_2_PATTERNS
	if tier == 3:
		return TIER_3_PATTERNS
	return TIER_4_PATTERNS

func _queue_single(speed: float, radius: float, delay: float) -> void:
	var side := rng.randi_range(0, 3)
	var lane := rng.randf_range(0.11, 0.89)
	for _attempt in range(3):
		if absf(lane - float(last_lane_by_side[side])) >= 0.08:
			break
		lane = rng.randf_range(0.11, 0.89)
	last_lane_by_side[side] = lane
	queue_projectile_warning(side, lane, speed, radius, delay)

func _queue_alternating(speed: float, radius: float, delay: float) -> void:
	var axis := pattern_step % 2
	var side := axis if pattern_step % 4 < 2 else axis + 2
	if pattern_step % 2 == 1:
		side = 1 if side == 0 else 0 if side == 1 else 3 if side == 2 else 2
	var lane := 0.22 + float((pattern_step * 3) % 6) * 0.11
	queue_projectile_warning(side, clampf(lane, 0.14, 0.86), speed, radius, delay)

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

func _queue_sweep(speed: float, radius: float, delay: float) -> void:
	var side := pattern_step % 4
	var centers := [0.22, 0.34, 0.46, 0.58, 0.70, 0.80]
	var center := float(centers[pattern_step % centers.size()])
	queue_projectile_warning(side, clampf(center - 0.09, 0.10, 0.90), speed, radius, delay)
	queue_projectile_warning(side, clampf(center + 0.09, 0.10, 0.90), speed * 1.02, radius, delay + 0.06)

func _queue_cross_fire(speed: float, radius: float, delay: float) -> void:
	var horizontal := pattern_step % 2 == 0
	var first := 0 if horizontal else 2
	var second := 1 if horizontal else 3
	var lane := rng.randf_range(0.22, 0.78)
	queue_projectile_warning(first, lane, speed, radius, delay)
	queue_projectile_warning(second, clampf(1.0 - lane, 0.18, 0.82), speed * 0.97, radius, delay + 0.10)
	var perpendicular := 2 if horizontal else 0
	queue_projectile_warning(perpendicular, rng.randf_range(0.25, 0.75), speed * 0.92, radius, delay + 0.18)

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

func _stepped_gap() -> float:
	var gaps := [0.28, 0.40, 0.52, 0.64, 0.72, 0.60, 0.48, 0.36]
	return float(gaps[pattern_step % gaps.size()])

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
	var phase_gain := minf(float(phase - 1) * 3.0, 72.0)
	var tier_gain := minf(float(tier - 1) * 9.0, 54.0)
	return minf(305.0, 168.0 + phase_gain + tier_gain)

func _warning_delay(phase: int, tier: int) -> float:
	var delay := 0.96 - float(phase - 1) * 0.010 - float(tier - 1) * 0.025
	return maxf(0.52, delay)

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
	if str(info["kind"]) == "normal":
		_pattern_for_info(info)
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
			tier_label.text = "TIER %d  //  %s" % [int(info["tier"]), _pattern_for_info(info)]
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
	return "Survive as long as possible.\n\n5 seconds of preparation.\n12-second phases rotate through different pressure patterns.\nEvery 5 phases triggers a boss protocol at roughly the one-minute mark.\nBoss clears grant a 5-second breather and replace the phase pool with harder patterns.\n\nEvery run begins at Phase 1 under the same progression rules."

func _get_pause_subtitle() -> String:
	return "ENDLESS MODE"

func _get_death_title() -> String:
	return "ENDLESS RUN ENDED"

func _get_death_subtitle() -> String:
	return "SURVIVAL PROTOCOL TERMINATED"

func _format_endless_time(seconds: float) -> String:
	var whole := maxi(0, int(floor(seconds)))
	return "%d:%02d" % [int(whole / 60), whole % 60]
