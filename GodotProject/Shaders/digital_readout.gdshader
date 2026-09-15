shader_type canvas_item;
render_mode unshaded;

// Opaque replacement for the example digits in the source display art.
// The surrounding bezel, printed heading and authored texture are preserved.
uniform vec4 surface_color : source_color = vec4(0.032, 0.021, 0.012, 1.0);

void fragment() {
	float grain = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453);
	float scanline = mod(floor(FRAGCOORD.y), 3.0) == 0.0 ? 0.88 : 1.0;
	COLOR = vec4(surface_color.rgb * (0.8 + grain * 0.4) * scanline, 1.0);
}
