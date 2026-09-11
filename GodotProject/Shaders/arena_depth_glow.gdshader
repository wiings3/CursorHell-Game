shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 glow_color : source_color = vec4(0.18, 0.32, 0.60, 1.0);
uniform vec2 rect_size = vec2(960.0, 896.0);
uniform vec2 arena_size = vec2(820.0, 756.0);

uniform float rim_strength : hint_range(0.0, 1.0) = 0.16;
uniform float halo_strength : hint_range(0.0, 0.5) = 0.055;
uniform float rim_falloff : hint_range(1.0, 24.0) = 4.5;
uniform float halo_falloff : hint_range(8.0, 100.0) = 36.0;
uniform float top_bias : hint_range(0.0, 0.5) = 0.16;
uniform float left_bias : hint_range(0.0, 0.5) = 0.06;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * rect_size;
	vec2 q = abs(p) - arena_size * 0.5;

	float signed_distance = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
	float outside_distance = max(signed_distance, 0.0);

	float rim = exp(-outside_distance / max(rim_falloff, 0.001));
	float halo = exp(-outside_distance / max(halo_falloff, 0.001));

	float directional = 1.0;
	directional += (1.0 - UV.y) * top_bias;
	directional += (1.0 - UV.x) * left_bias;

	float outside_mask = smoothstep(-2.0, 1.0, signed_distance);
	float intensity = (rim * rim_strength + halo * halo_strength) * directional * outside_mask;

	COLOR = vec4(glow_color.rgb * intensity, glow_color.a * intensity);
}
