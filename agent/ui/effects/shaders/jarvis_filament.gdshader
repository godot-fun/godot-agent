shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

uniform vec4 line_color : source_color = vec4(0.0, 1.0, 1.0, 0.45);
uniform float flow_speed : hint_range(0.0, 6.0) = 1.8;
uniform float pulse : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	float flow = fract(UV.x * 6.0 - TIME * flow_speed);
	float stripe = smoothstep(0.0, 0.12, flow) * (1.0 - smoothstep(0.12, 0.28, flow));
	vec3 col = line_color.rgb * (0.35 + stripe * 1.4) * pulse;
	ALBEDO = col;
	EMISSION = col * 1.2;
	ALPHA = line_color.a * pulse;
}
