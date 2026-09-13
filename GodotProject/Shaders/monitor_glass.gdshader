shader_type canvas_item;

uniform vec4 glass_tint : source_color = vec4(0.10, 0.14, 0.17, 1.0);
uniform float scanline_strength : hint_range(0.0, 0.2) = 0.032;
uniform float vignette_strength : hint_range(0.0, 0.2) = 0.075;
uniform float grime_strength : hint_range(0.0, 0.12) = 0.025;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 19.19);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	float scan = 0.5 + 0.5 * sin(uv.y * 756.0 * 3.14159265);
	float dist_edge = max(abs(uv.x - 0.5) * 2.0, abs(uv.y - 0.5) * 2.0);
	float edge = smoothstep(0.72, 1.0, dist_edge);

	vec2 grime_cell = floor(uv * vec2(120.0, 94.0));
	float dust = smoothstep(0.94, 0.995, hash21(grime_cell));

	float corner_glare = exp(-distance(uv, vec2(0.20, 0.08)) * 12.0) * 0.018;
	float alpha = 0.010 + scan * scanline_strength + edge * vignette_strength + dust * grime_strength + corner_glare;
	vec3 color = glass_tint.rgb;
	COLOR = vec4(color, clamp(alpha, 0.0, 0.18));
}
