shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Flat marker drawn on the ground: range rings, aim lines, danger zones.
// A PlaneMesh carries it; UV 0..1 covers the plane.

uniform vec4 color : source_color = vec4(1.0, 0.45, 0.1, 1.0);
uniform float ring_width = 0.05;
uniform float fill_alpha = 0.12;
uniform float progress = 1.0; // warning circles fill from the centre while < 1
uniform float alpha = 1.0;
uniform float glow = 1.0; // > 1 pushes the colour into HDR so it blooms
uniform int shape = 0; // 0 = circle, 1 = rectangle

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = 0.0;
	if (shape == 0) {
		float d = length(p);
		if (d > 1.0) {
			discard;
		}
		float edge = smoothstep(1.0 - ring_width * 2.0, 1.0 - ring_width, d);
		float inside = 1.0 - step(progress, d);
		float fill = fill_alpha * inside;
		float growing = 1.0 - step(0.999, progress);
		float front = inside * smoothstep(progress - 0.08, progress, d) * 0.7 * growing;
		a = max(max(edge, fill), front);
	} else {
		vec2 q = abs(p);
		float ex = smoothstep(1.0 - ring_width * 2.0, 1.0 - ring_width, q.x);
		float ey = smoothstep(1.0 - ring_width * 2.0, 1.0 - ring_width, q.y);
		float fade = mix(1.0, 0.45, UV.y);
		a = max(max(ex, ey), fill_alpha) * fade;
	}
	ALBEDO = color.rgb * glow;
	ALPHA = clamp(a * color.a * alpha, 0.0, 1.0);
}
