shader_type spatial;
render_mode depth_draw_opaque, cull_disabled;

uniform vec4 rock_color : source_color = vec4(0.35, 0.40, 0.38, 1.0);
uniform vec4 accent_color : source_color = vec4(0.28, 0.33, 0.31, 1.0);

varying float facet_tone;
varying float upwardness;

void vertex() {
	facet_tone = COLOR.g;
	upwardness = clamp(NORMAL.y, 0.0, 1.0);
}

void fragment() {
	vec3 facet = mix(accent_color.rgb, rock_color.rgb, 0.45 + facet_tone * 0.4);
	facet *= mix(0.88, 1.06, upwardness) * mix(0.95, 1.04, facet_tone);
	ALBEDO = facet;
	ROUGHNESS = 0.94;
	SPECULAR = 0.18;
	METALLIC = 0.0;
}
