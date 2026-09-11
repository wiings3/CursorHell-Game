shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.02, 0.72);
uniform vec2 rect_size = vec2(960.0, 896.0);
uniform vec2 arena_size = vec2(820.0, 756.0);
uniform vec2 shadow_offset = vec2(10.0, 14.0);

uniform float shadow_strength : hint_range(0.0, 1.0) = 0.34;
uniform float contact_strength : hint_range(0.0, 1.0) = 0.20;
uniform float softness : hint_range(4.0, 80.0) = 24.0;
uniform float contact_softness : hint_range(1.0, 24.0) = 5.0;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * rect_size - shadow_offset;
	vec2 q = abs(p) - arena_size * 0.5;

	float signed_distance = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
	float outside_distance = max(signed_distance, 0.0);
	float outside_mask = smoothstep(-2.0, 1.0, signed_distance);

	float soft_shadow = exp(-outside_distance / max(softness, 0.001)) * shadow_strength;
	float contact_shadow = exp(-outside_distance / max(contact_softness, 0.001)) * contact_strength;
	float alpha = (soft_shadow + contact_shadow) * outside_mask * shadow_color.a;

	COLOR = vec4(shadow_color.rgb, alpha);
}
