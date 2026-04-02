// Outline pass for flat billboard-like quads.
// Use this as material next_pass on top of the base Y-billboard material.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

uniform vec4 outline_color : source_color = vec4(1.0, 0.92, 0.2, 1.0);
uniform float expand_amount : hint_range(0.0, 0.35) = 0.08;
uniform float outline_width : hint_range(0.001, 0.35) = 0.08;

void vertex() {
	// Grow in-plane from the quad center to expose a border outside the base sprite.
	vec2 dir2 = VERTEX.xy;
	float len_sq = dot(dir2, dir2);
	if (len_sq > 0.000001) {
		VERTEX.xy += normalize(dir2) * expand_amount;
	}
}

void fragment() {
	// Draw only near UV borders so the interior stays transparent.
	float edge_x = min(UV.x, 1.0 - UV.x);
	float edge_y = min(UV.y, 1.0 - UV.y);
	float edge_dist = min(edge_x, edge_y);
	float edge_mask = 1.0 - smoothstep(outline_width, outline_width + 0.01, edge_dist);
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a * edge_mask;
}
