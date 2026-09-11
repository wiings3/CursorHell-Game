shader_type canvas_item;
render_mode unshaded;

uniform vec4 accent_color : source_color = vec4(1.0, 0.58, 0.15, 1.0);
uniform float vignette_strength : hint_range(0.0, 0.7) = 0.26;
uniform float scanline_strength : hint_range(0.0, 0.12) = 0.022;
uniform float grain_strength : hint_range(0.0, 0.08) = 0.012;
uniform float sweep_strength : hint_range(0.0, 0.15) = 0.045;
uniform float rim_strength : hint_range(0.0, 0.2) = 0.055;
uniform vec2 arena_pixels = vec2(820.0, 756.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 centered = uv * 2.0 - 1.0;
	float distance_from_center = length(centered * vec2(0.92, 1.0));
	float vignette = smoothstep(0.42, 1.16, distance_from_center) * vignette_strength;

	float scan_wave = 0.5 + 0.5 * sin(uv.y * arena_pixels.y * 3.14159265);
	float scanlines = scan_wave * scanline_strength;

	vec2 grain_cell = floor(uv * arena_pixels) + floor(TIME * 20.0);
	float grain = abs(hash21(grain_cell) - 0.5) * 2.0 * grain_strength;

	float sweep_y = fract(TIME * 0.045);
	float sweep = exp(-pow((uv.y - sweep_y) * 20.0, 2.0)) * sweep_strength;

	float edge_distance = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float rim_pulse = 0.78 + 0.22 * sin(TIME * 1.7);
	float rim = (1.0 - smoothstep(0.0, 0.022, edge_distance)) * rim_strength * rim_pulse;

	float accent_alpha = sweep + rim;
	float dark_alpha = vignette + scanlines + grain;
	float total_alpha = clamp(accent_alpha + dark_alpha, 0.0, 0.38);
	vec3 overlay_rgb = accent_color.rgb * (accent_alpha / max(total_alpha, 0.0001));

	COLOR = vec4(overlay_rgb, total_alpha);
}
