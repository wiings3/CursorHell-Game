shader_type canvas_item;

uniform vec4 metal_dark : source_color = vec4(0.075, 0.068, 0.060, 1.0);
uniform vec4 metal_light : source_color = vec4(0.235, 0.215, 0.185, 1.0);
uniform vec4 rust_color : source_color = vec4(0.28, 0.095, 0.030, 1.0);
uniform float rust_amount : hint_range(0.0, 1.0) = 0.58;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	float broad = value_noise(uv * vec2(7.0, 5.0));
	float fine = value_noise(uv * vec2(54.0, 46.0));
	float vertical = value_noise(vec2(uv.x * 22.0, uv.y * 2.0));

	vec3 color = mix(metal_dark.rgb, metal_light.rgb, 0.28 + broad * 0.32);
	color *= 0.80 + fine * 0.22;

	float rust = smoothstep(0.56, 0.82, broad + vertical * 0.24);
	rust *= rust_amount;
	color = mix(color, rust_color.rgb * (0.70 + fine * 0.40), rust);

	float streak = smoothstep(0.64, 0.91, vertical) * smoothstep(0.08, 0.90, uv.y);
	color = mix(color, rust_color.rgb * 0.52, streak * rust_amount * 0.42);

	float scratch_h = smoothstep(0.975, 0.996, hash21(vec2(floor(uv.y * 190.0), floor(uv.x * 8.0))));
	float scratch_v = smoothstep(0.982, 0.998, hash21(vec2(floor(uv.x * 240.0), floor(uv.y * 7.0))));
	color += vec3(0.09, 0.075, 0.055) * max(scratch_h, scratch_v) * 0.45;

	float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float edge_wear = 1.0 - smoothstep(0.0, 0.075, edge);
	color += vec3(0.055, 0.048, 0.038) * edge_wear;

	COLOR = vec4(color, 1.0);
}
