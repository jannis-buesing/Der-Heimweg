shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_always;

uniform vec4 fog_color : source_color = vec4(0.008, 0.012, 0.02, 1.0);
uniform float fog_density : hint_range(0.0, 1.0) = 1.0;
uniform float edge_softness : hint_range(0.01, 1.0) = 0.3;

void fragment() {
	// UV.x ranges from 0.0 at inner edge (road side) to 1.0 at outer edge (deep forest)
	// Rapidly ramps up to 1.0 (completely opaque) to form a dense dark forest fog wall
	float edge_fade = smoothstep(0.0, edge_softness, UV.x);
	
	// Soft vertical fade at the very top edge so fog blends seamlessly into dark sky
	float vertical_fade = smoothstep(1.0, 0.8, UV.y);
	
	float alpha = edge_fade * vertical_fade * fog_density;
	
	ALBEDO = fog_color.rgb;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
