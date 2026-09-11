shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 glow_color : source_color = vec4(0.18, 0.32, 0.60, 1.0);

uniform vec2 rect_size = vec2(940.0, 876.0);
uniform float padding = 60.0;

uniform float rim_strength : hint_range(0.0, 1.0) = 0.18;
uniform float halo_strength : hint_range(0.0, 1.0) = 0.08;

uniform float rim_size : hint_range(1.0, 30.0) = 5.0;
uniform float halo_size : hint_range(5.0, 100.0) = 42.0;

void fragment() {
	vec2 p = UV * rect_size;

	vec2 inner_min = vec2(padding);
	vec2 inner_max = rect_size - vec2(padding);

	vec2 outside = max(
		max(inner_min - p, p - inner_max),
		vec2(0.0)
	);

	float d = length(outside);

	float rim = exp(-d / rim_size);
	float halo = exp(-d / halo_size);

	float intensity =
		rim * rim_strength +
		halo * halo_strength;

	// Slight directional lighting.
	float light_bias = mix(
		0.70,
		1.15,
		1.0 - clamp((UV.x + UV.y) * 0.5, 0.0, 1.0)
	);

	intensity *= light_bias;

	COLOR = vec4(
		glow_color.rgb * intensity,
		intensity
	);
}