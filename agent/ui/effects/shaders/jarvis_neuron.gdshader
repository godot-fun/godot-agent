shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_back, unshaded;

uniform vec4 base_color : source_color = vec4(0.0, 0.9, 1.0, 0.85);
uniform float pulse : hint_range(0.0, 2.0) = 1.0;
uniform float emission_scale : hint_range(0.5, 3.0) = 1.65;

varying float flicker_phase;
varying float flicker_speed;
varying float local_pulse;

void vertex() {
	flicker_phase = INSTANCE_CUSTOM.r * 6.28318;
	flicker_speed = 1.6 + INSTANCE_CUSTOM.g * 2.4;
	local_pulse = pulse * (0.72 + INSTANCE_CUSTOM.b * 0.45);
}

void fragment() {
	float flicker = 0.82 + 0.18 * sin(TIME * flicker_speed + flicker_phase + VERTEX.x * 4.0 + VERTEX.z * 3.0);
	vec3 col = base_color.rgb * local_pulse * flicker;
	ALBEDO = col;
	EMISSION = col * emission_scale;
	ALPHA = base_color.a * local_pulse * (0.82 + flicker * 0.18);
}
