extends Node2D
class_name CursorHellRouteLaser

const ARENA := Rect2(390.0, 72.0, 820.0, 756.0)

@onready var glow: Line2D = $Glow
@onready var core: Line2D = $Core

var orientation := "vertical"
var coordinate := 800.0
var charge_time := 1.05
var lethal_time := 1.20
var beam_width := 22.0
var state := "dormant"
var state_time := 0.0

var sweep_enabled := false
var sweep_from := 800.0
var sweep_to := 800.0

var gap_enabled := false
var gap_center := 450.0
var gap_size := 170.0
var secondary_glow: Line2D
var secondary_core: Line2D

func _ready() -> void:
	_ensure_secondary_lines()
	_refresh_auto_gap()
	_apply_geometry()
	_apply_visuals()

func configure(new_orientation: String, new_coordinate: float, new_charge_time: float = 1.05, new_lethal_time: float = 1.20, new_beam_width: float = 22.0) -> void:
	orientation = "horizontal" if new_orientation == "horizontal" else "vertical"
	coordinate = new_coordinate
	charge_time = maxf(new_charge_time, 0.15)
	lethal_time = maxf(new_lethal_time, 0.15)
	beam_width = maxf(new_beam_width, 4.0)
	sweep_enabled = false
	sweep_from = coordinate
	sweep_to = coordinate
	_refresh_auto_gap()
	if is_node_ready():
		_apply_geometry()
		_apply_visuals()

func configure_sweep(new_from: float, new_to: float) -> void:
	sweep_enabled = true
	sweep_from = new_from
	sweep_to = new_to
	coordinate = sweep_from
	if is_node_ready():
		_apply_geometry()

func configure_gap(new_center: float, new_size: float = 170.0) -> void:
	gap_enabled = true
	gap_size = maxf(new_size, beam_width + 32.0)
	gap_center = _clamp_gap_center(new_center)
	if is_node_ready():
		_apply_geometry()

func clear_gap() -> void:
	gap_enabled = false
	if is_node_ready():
		_apply_geometry()

func prime() -> void:
	if state != "dormant":
		return
	state = "charging"
	state_time = 0.0
	_refresh_auto_gap()
	if sweep_enabled:
		coordinate = sweep_from
		_apply_geometry()
	_apply_visuals()

func reset_laser() -> void:
	state = "dormant"
	state_time = 0.0
	_refresh_auto_gap()
	if sweep_enabled:
		coordinate = sweep_from
		_apply_geometry()
	_apply_visuals()

func is_lethal() -> bool:
	return state == "lethal"

func _process(delta: float) -> void:
	if state == "dormant" or state == "spent":
		return

	state_time += delta
	if state == "charging":
		var pulse := 0.5 + 0.5 * sin(state_time * 18.0)
		glow.modulate.a = 0.28 + pulse * 0.42
		core.modulate.a = 0.45 + pulse * 0.45
		_sync_secondary_style()
		if state_time >= charge_time:
			state = "lethal"
			state_time = 0.0
			_apply_visuals()
	elif state == "lethal":
		if sweep_enabled:
			var sweep_progress := clampf(state_time / maxf(lethal_time, 0.001), 0.0, 1.0)
			coordinate = lerpf(sweep_from, sweep_to, sweep_progress)
			_apply_geometry()
		var pulse := 0.72 + 0.28 * absf(sin(state_time * 28.0))
		glow.modulate.a = pulse
		core.modulate.a = 1.0
		_sync_secondary_style()
		if state_time >= lethal_time:
			state = "spent"
			state_time = 0.0
			_apply_visuals()

func contains_point(point: Vector2) -> bool:
	if not is_lethal() or not ARENA.has_point(point):
		return false
	if orientation == "vertical":
		if absf(point.x - coordinate) > beam_width * 0.5:
			return false
		return not _is_in_gap(point.y)
	if absf(point.y - coordinate) > beam_width * 0.5:
		return false
	return not _is_in_gap(point.x)

func intersects_segment(start: Vector2, finish: Vector2) -> bool:
	if not is_lethal():
		return false
	if contains_point(start) or contains_point(finish):
		return true

	if orientation == "vertical":
		var dx := finish.x - start.x
		if absf(dx) <= 0.0001:
			return false
		var vertical_t := (coordinate - start.x) / dx
		if vertical_t < 0.0 or vertical_t > 1.0:
			return false
		var crossing_y := lerpf(start.y, finish.y, vertical_t)
		if crossing_y < ARENA.position.y or crossing_y > ARENA.end.y:
			return false
		return not _is_in_gap(crossing_y)

	var dy := finish.y - start.y
	if absf(dy) <= 0.0001:
		return false
	var horizontal_t := (coordinate - start.y) / dy
	if horizontal_t < 0.0 or horizontal_t > 1.0:
		return false
	var crossing_x := lerpf(start.x, finish.x, horizontal_t)
	if crossing_x < ARENA.position.x or crossing_x > ARENA.end.x:
		return false
	return not _is_in_gap(crossing_x)

func _refresh_auto_gap() -> void:
	if get_parent() == null or not bool(get_parent().get_meta("auto_player_gap", false)):
		return
	var arena_content := get_parent().get_parent()
	if arena_content == null:
		return
	var player_node := arena_content.get_node_or_null("Player") as Node2D
	if player_node == null:
		return
	gap_enabled = true
	gap_size = maxf(float(get_parent().get_meta("laser_gap_size", 170.0)), beam_width + 32.0)
	var desired_center := player_node.position.y if orientation == "vertical" else player_node.position.x
	gap_center = _clamp_gap_center(desired_center)

func _clamp_gap_center(value: float) -> float:
	var half_gap := gap_size * 0.5
	if orientation == "vertical":
		return clampf(value, ARENA.position.y + half_gap, ARENA.end.y - half_gap)
	return clampf(value, ARENA.position.x + half_gap, ARENA.end.x - half_gap)

func _is_in_gap(along_beam_coordinate: float) -> bool:
	if not gap_enabled:
		return false
	return absf(along_beam_coordinate - gap_center) <= gap_size * 0.5

func _ensure_secondary_lines() -> void:
	if secondary_glow == null:
		secondary_glow = glow.duplicate() as Line2D
		secondary_glow.name = "GapGlow"
		add_child(secondary_glow)
	if secondary_core == null:
		secondary_core = core.duplicate() as Line2D
		secondary_core.name = "GapCore"
		add_child(secondary_core)

func _apply_geometry() -> void:
	if not is_instance_valid(glow) or not is_instance_valid(core):
		return
	_ensure_secondary_lines()

	if not gap_enabled:
		if orientation == "vertical":
			var vertical_points := PackedVector2Array([Vector2(coordinate, ARENA.position.y), Vector2(coordinate, ARENA.end.y)])
			glow.points = vertical_points
			core.points = vertical_points
		else:
			var horizontal_points := PackedVector2Array([Vector2(ARENA.position.x, coordinate), Vector2(ARENA.end.x, coordinate)])
			glow.points = horizontal_points
			core.points = horizontal_points
		secondary_glow.visible = false
		secondary_core.visible = false
	else:
		gap_center = _clamp_gap_center(gap_center)
		var gap_start := gap_center - gap_size * 0.5
		var gap_end := gap_center + gap_size * 0.5
		secondary_glow.visible = true
		secondary_core.visible = true
		if orientation == "vertical":
			var first_vertical := PackedVector2Array([Vector2(coordinate, ARENA.position.y), Vector2(coordinate, gap_start)])
			var second_vertical := PackedVector2Array([Vector2(coordinate, gap_end), Vector2(coordinate, ARENA.end.y)])
			glow.points = first_vertical
			core.points = first_vertical
			secondary_glow.points = second_vertical
			secondary_core.points = second_vertical
		else:
			var first_horizontal := PackedVector2Array([Vector2(ARENA.position.x, coordinate), Vector2(gap_start, coordinate)])
			var second_horizontal := PackedVector2Array([Vector2(gap_end, coordinate), Vector2(ARENA.end.x, coordinate)])
			glow.points = first_horizontal
			core.points = first_horizontal
			secondary_glow.points = second_horizontal
			secondary_core.points = second_horizontal

	glow.width = beam_width
	core.width = maxf(2.0, beam_width * 0.16)
	secondary_glow.width = glow.width
	secondary_core.width = core.width
	_sync_secondary_style()

func _apply_visuals() -> void:
	if not is_instance_valid(glow) or not is_instance_valid(core):
		return
	match state:
		"dormant":
			glow.default_color = Color(0.78, 0.42, 0.18, 0.20)
			core.default_color = Color(1.0, 0.67, 0.28, 0.34)
			glow.modulate.a = 0.24
			core.modulate.a = 0.34
		"charging":
			glow.default_color = Color(1.0, 0.36, 0.10, 0.82)
			core.default_color = Color(1.0, 0.82, 0.36, 1.0)
			glow.modulate.a = 0.55
			core.modulate.a = 0.85
		"lethal":
			glow.default_color = Color(1.0, 0.08, 0.04, 0.92)
			core.default_color = Color(1.0, 0.96, 0.80, 1.0)
			glow.modulate.a = 1.0
			core.modulate.a = 1.0
		_:
			glow.default_color = Color(0.28, 0.24, 0.18, 0.10)
			core.default_color = Color(0.50, 0.43, 0.32, 0.12)
			glow.modulate.a = 0.12
			core.modulate.a = 0.16
	_sync_secondary_style()

func _sync_secondary_style() -> void:
	if not is_instance_valid(secondary_glow) or not is_instance_valid(secondary_core):
		return
	secondary_glow.default_color = glow.default_color
	secondary_core.default_color = core.default_color
	secondary_glow.modulate = glow.modulate
	secondary_core.modulate = core.modulate
