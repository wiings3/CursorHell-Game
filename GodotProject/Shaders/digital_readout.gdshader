shader_type canvas_item;
render_mode unshaded;

// Keep gameplay HUD readout surfaces deliberately simple and driver-safe.
// The cabinet-wide CRT treatment is handled elsewhere; this shader only fills
// the small timer/score display backgrounds.
uniform vec4 surface_color : source_color = vec4(0.032, 0.021, 0.012, 1.0);

void fragment() {
	COLOR = surface_color;
}
