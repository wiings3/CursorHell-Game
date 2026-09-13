shader_type canvas_item;

uniform vec4 concrete_dark : source_color = vec4(0.018, 0.020, 0.024, 1.0);
uniform vec4 concrete_mid : source_color = vec4(0.070, 0.064, 0.058, 1.0);
uniform vec4 damp_tint : source_color = vec4(0.035, 0.052, 0.050, 1.0);
uniform float grime_strength : hint_range(0.0, 1.0) = 0.72;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
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
	float broad = value_noise(uv * vec2(5.0, 4.0));
	float medium = value_noise(uv * vec2(18.0, 14.0));
	float fine = value_noise(uv * vec2(82.0, 66.0));

	vec3 color = mix(concrete_dark.rgb, concrete_mid.rgb, 0.22 + broad * 0.30);
	color *= 0.76 + medium * 0.28;

	float damp = smoothstep(0.57, 0.88, value_noise(vec2(uv.x * 9.0, uv.y * 2.5 + broad * 2.0)));
	color = mix(color, damp_tint.rgb, damp * grime_strength * 0.58);

	float vertical_stain = smoothstep(0.68, 0.92, value_noise(vec2(uv.x * 26.0, uv.y * 1.4)));
	vertical_stain *= smoothstep(0.08, 0.78, uv.y);
	color *= 1.0 - vertical_stain * 0.22 * grime_strength;

	float speck = smoothstep(0.84, 0.98, fine);
	color *= 1.0 - speck * 0.19;

	float cold_light = exp(-distance(uv, vec2(0.86, 0.16)) * 6.0) * 0.10;
	color += vec3(0.08, 0.10, 0.11) * cold_light;

	float vignette = 1.0 - smoothstep(0.26, 0.82, distance(uv, vec2(0.5)));
	color *= mix(0.45, 1.0, vignette);

	COLOR = vec4(color, 1.0);
}
