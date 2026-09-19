shader_type spatial;
render_mode cull_disabled, depth_draw_always;

uniform vec4 fog_color : source_color = vec4(0.015, 0.02, 0.035, 1.0);
uniform float fog_density : hint_range(0.0, 1.0) = 1.0;
uniform float edge_softness : hint_range(0.01, 2.0) = 0.5;

void fragment() {
	// UV.x ranges from 0.0 at inner edge (road side) to 1.0 at outer edge (deep forest)
	// Smooth transition from 0.0 opacity at inner edge to 1.0 opacity (100% sight blocking) at outer edge.
	float edge_fade = smoothstep(0.0, edge_softness, UV.x);
	
	// Vertical fade near top of fog volume (UV.y goes from 0.0 at bottom to 1.0 at top)
	float vertical_fade = smoothstep(1.0, 0.7, UV.y) * smoothstep(0.0, 0.02, UV.y);
	
	float alpha = edge_fade * vertical_fade * fog_density;
	
	ALBEDO = fog_color.rgb;
	ALPHA = clamp(alpha, 0.0, 1.0);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
