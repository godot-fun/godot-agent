shader_type spatial;
render_mode blend_add, depth_test_disabled, cull_disabled, unshaded;

uniform vec4 line_color : source_color = vec4(0.82, 0.38, 1.0, 0.55);
uniform vec4 flow_color : source_color = vec4(1.0, 0.92, 0.72, 1.0);
uniform float flow_speed : hint_range(0.0, 6.0) = 2.2;
uniform float pulse : hint_range(0.0, 2.0) = 1.0;
uniform float emission_scale : hint_range(0.5, 3.0) = 1.45;

void fragment() {
	float edge = 1.0 - abs(UV.y - 0.5) * 2.0;
	edge = pow(clamp(edge, 0.0, 1.0), 1.35);
	float flow = fract(UV.x * 5.0 - TIME * flow_speed);
	float stripe = smoothstep(0.0, 0.1, flow) * (1.0 - smoothstep(0.1, 0.26, flow));
	vec3 base = line_color.rgb * (0.28 + edge * 0.55) * pulse;
	vec3 col = base + flow_color.rgb * stripe * 0.85 * pulse;
	ALBEDO = col;
	EMISSION = col * emission_scale;
	ALPHA = line_color.a * edge * pulse;
}
