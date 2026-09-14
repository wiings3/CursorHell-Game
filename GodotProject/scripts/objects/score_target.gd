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

var age := 0.0
var consumed := false

func _ready() -> void:
	_update_purge_ring_radius()

func _process(delta: float) -> void:
	if consumed:
		return

	age += delta
	var remaining := maxf(0.0, lifetime - age)
	var pulse := 0.5 + 0.5 * sin(age * 7.0)
	var urgency := clampf(1.0 - remaining / maxf(lifetime, 0.001), 0.0, 1.0)

	outer_ring.scale = Vector2.ONE * (1.0 + 0.06 * pulse)
	core.scale = Vector2.ONE * (0.92 + 0.10 * pulse)
	cross_h.modulate.a = 0.72 + 0.22 * pulse
	cross_v.modulate.a = cross_h.modulate.a
	purge_ring.modulate.a = 0.18 + 0.10 * pulse + 0.10 * urgency

	if remaining <= 1.0:
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
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE * 1.45, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.finished.connect(func() -> void: queue_free())

func _update_purge_ring_radius() -> void:
	if purge_ring == null:
		return
	var authored_radius := 145.0
	var ratio := purge_radius / authored_radius if authored_radius > 0.0 else 1.0
	purge_ring.scale = Vector2.ONE * ratio
