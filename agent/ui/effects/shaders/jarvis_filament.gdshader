shader_type spatial;
render_mode blend_add, depth_test_disabled, cull_disabled, unshaded;

uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float line_strength : hint_range(0.0, 1.5) = 0.52;

void fragment() {
	vec3 col = line_color.rgb * line_strength;
	ALBEDO = col;
	EMISSION = col;
}
