extends Node2D
class_name CursorHellScoreTarget

signal expired(target: CursorHellScoreTarget)

@export var hit_radius: float = 30.0
@export var purge_radius: float = 145.0
@export var score_bonus: int = 1500
@export var lifetime: float = 5.5

@onready var purge_ring: Line2D = $PurgeRing
@onready var outer_ring: Line2D = $OuterRing
@onready var core: Polygon2D = $Core
@onready var cross_h: Line2D = $CrossH
@onready var cross_v: Line2D = $CrossV
@onready var stage_label: Label = $StageLabel

var age := 0.0
var consumed := false
var chain_step := 1
var chain_total := 4

func _ready() -> void:
	_update_purge_ring_radius()
	_apply_chain_style()

func configure_chain(step: int, total: int, new_lifetime: float, new_purge_radius: float, new_score_bonus: int) -> void:
	chain_step = clampi(step, 1, maxi(total, 1))
	chain_total = maxi(total, 1)
	lifetime = maxf(new_lifetime, 0.25)
	purge_radius = maxf(new_purge_radius, hit_radius)
	score_bonus = maxi(new_score_bonus, 0)
	age = 0.0
	if is_node_ready():
		_update_purge_ring_radius()
		_apply_chain_style()

func _process(delta: float) -> void:
	if consumed:
		return

	age += delta
	var remaining := maxf(0.0, lifetime - age)
	var pulse_speed := 7.0 + float(chain_step - 1) * 1.8
	var pulse := 0.5 + 0.5 * sin(age * pulse_speed)
	var urgency := clampf(1.0 - remaining / maxf(lifetime, 0.001), 0.0, 1.0)
	var stage_energy := float(chain_step - 1) / float(maxi(chain_total - 1, 1))

	outer_ring.scale = Vector2.ONE * (1.0 + (0.06 + stage_energy * 0.035) * pulse)
	core.scale = Vector2.ONE * (0.92 + (0.10 + stage_energy * 0.05) * pulse)
	cross_h.modulate.a = 0.72 + 0.22 * pulse
	cross_v.modulate.a = cross_h.modulate.a
	purge_ring.modulate.a = 0.18 + 0.10 * pulse + 0.10 * urgency + 0.08 * stage_energy

	if remaining <= 0.8:
		var blink := 0.42 + 0.58 * absf(sin(age * 18.0))
		modulate.a = blink
	else:
		modulate.a = 1.0

	if age >= lifetime:
		expired.emit(self)
		queue_free()

func contains_point(point: Vector2) -> bool:
	return not consumed and global_position.distance_to(point) <= hit_radius

func consume() -> void:
	if consumed:
		return
	consumed = true
	set_process(false)
	var finisher_scale := 1.70 if chain_step >= chain_total else 1.45
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE * finisher_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.finished.connect(func() -> void: queue_free())

func _apply_chain_style() -> void:
	if not is_instance_valid(outer_ring):
		return
	var energy := float(chain_step - 1) / float(maxi(chain_total - 1, 1))
	var ring_color := Color(0.20 + energy * 0.72, 0.92 + energy * 0.08, 1.0, 0.95)
	var core_color := Color(0.72 + energy * 0.28, 1.0, 1.0, 0.98)
	outer_ring.default_color = ring_color
	outer_ring.width = 4.0 + energy * 2.0
	core.color = core_color
	cross_h.default_color = core_color
	cross_v.default_color = core_color
	stage_label.text = "%d/%d" % [chain_step, chain_total]
	stage_label.add_theme_color_override("font_color", core_color)
	stage_label.scale = Vector2.ONE * (1.0 + energy * 0.12)

func _update_purge_ring_radius() -> void:
	if purge_ring == null:
		return
	var authored_radius := 145.0
	var ratio := purge_radius / authored_radius if authored_radius > 0.0 else 1.0
	purge_ring.scale = Vector2.ONE * ratio
