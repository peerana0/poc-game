shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// Dirt road drawn on a ribbon mesh. UV.x runs across the road (0..1),
// UV.y along it in road widths. Edges fade into the grass.

uniform sampler2D dirt : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec4 center_color : source_color = vec4(0.66, 0.54, 0.38, 1.0);
uniform vec4 edge_color : source_color = vec4(0.42, 0.36, 0.24, 1.0);

void fragment() {
	float d = texture(dirt, vec2(UV.x * 0.5, UV.y * 0.35)).r;
	float edge = abs(UV.x - 0.5) * 2.0;
	vec3 col = mix(center_color.rgb, edge_color.rgb, smoothstep(0.45, 0.95, edge));
	col *= 0.78 + d * 0.45;
	ALBEDO = col;
	ROUGHNESS = 0.95;
	ALPHA = 1.0 - smoothstep(0.72, 1.0, edge + (d - 0.5) * 0.2);
}
