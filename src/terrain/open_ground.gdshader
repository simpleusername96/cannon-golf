shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// Keep the photographic source subordinate to the low-poly mountain while
// retaining enough variation and lighting response to visually anchor it.
uniform sampler2D ground_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 base_color : source_color = vec4(0.62, 0.66, 0.48, 1.0);
uniform float world_scale : hint_range(0.005, 0.1, 0.001) = 0.032;
uniform float detail_strength : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float source_saturation : hint_range(0.0, 1.0, 0.01) = 0.15;

varying vec3 world_position;


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	vec3 source = texture(ground_albedo, world_position.xz * world_scale).rgb;
	float luminance = dot(source, vec3(0.2126, 0.7152, 0.0722));
	vec3 muted_source = mix(vec3(luminance), source, source_saturation);
	muted_source = (muted_source - vec3(0.5)) * 0.45 + vec3(0.5);
	ALBEDO = mix(base_color.rgb, muted_source, detail_strength);
	ROUGHNESS = 0.94;
}
