extends Node2D
class_name CursorHellPlayer

@onready var visual_root: Node2D = $VisualRoot
@onready var glow_large: Polygon2D = $VisualRoot/GlowLarge
@onready var glow_inner: Polygon2D = $VisualRoot/GlowInner
@onready var reticle_ring: Node2D = $VisualRoot/ReticleRing
@onready var hitbox_ring: Line2D = $VisualRoot/HitboxRing

var pulse: float = 0.0
var danger_flash: float = 0.0
var glow_large_base_scale := Vector2.ONE
var glow_inner_base_scale := Vector2.ONE

func _ready() -> void:
	# All actual player art lives in Player.tscn so it is visible and editable in
	# the 2D editor. This script only supplies lightweight runtime animation.
	glow_large_base_scale = glow_large.scale
	glow_inner_base_scale = glow_inner.scale

func _process(delta: float) -> void:
	pulse += delta * 4.0
	danger_flash = maxf(0.0, danger_flash - delta * 4.0)

	var pulse_wave := 0.5 + 0.5 * sin(pulse)
	reticle_ring.rotation = pulse * 0.20

	# Preserve whatever base size is authored in the scene and only animate around
	# it, so changing the visual nodes in the editor remains the source of truth.
	glow_large.scale = glow_large_base_scale * (1.0 + pulse_wave * 0.045 + danger_flash * 0.10)
	glow_inner.scale = glow_inner_base_scale * (1.0 + pulse_wave * 0.025 + danger_flash * 0.06)
	reticle_ring.modulate.a = clampf(0.72 + danger_flash * 0.28, 0.0, 1.0)
	hitbox_ring.modulate.a = clampf(0.76 + danger_flash * 0.24, 0.0, 1.0)

func flash_near_miss() -> void:
	danger_flash = 1.0
