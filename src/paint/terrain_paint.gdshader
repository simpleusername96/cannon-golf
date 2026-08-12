shader_type spatial;
render_mode depth_draw_opaque, cull_disabled;

uniform sampler2D paint_mask : filter_linear, repeat_disable;
uniform sampler2D target_mask : filter_nearest, repeat_disable;
// Keep the mountain one readable value step below the bright wall and apron.
// The aiming camera receives a strong daylight key, so near-white albedo
// collapses every facet to a flat white silhouette.
uniform vec4 rock_color : source_color = vec4(0.176, 0.227, 0.314, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.063, 0.091, 0.150, 1.0);
uniform vec4 paint_color : source_color = vec4(0.03, 0.38, 1.0, 1.0);
uniform float support_floor_y = -2.0;
uniform float support_rear_z = -172.0;

varying float paintable_surface;
varying float upwardness;
varying float facet_tone;
varying vec3 world_position;

void vertex() {
	paintable_surface = COLOR.r;
	upwardness = clamp(NORMAL.y, 0.0, 1.0);
	facet_tone = COLOR.g;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The top falloff terminates on the apron plane. Suppress the coplanar final
	// millimetres so the shared join cannot shimmer into saw-tooth fragments.
	if (paintable_surface >= 0.5 && world_position.y <= support_floor_y + 0.03) {
		discard;
	}
	// The support shell closes terrain collision below the shared world floor.
	// Only its above-floor cliffs belong in the visible mountain silhouette.
	if (paintable_surface < 0.5 && (
		world_position.y <= support_floor_y + 0.005 ||
		world_position.z <= support_rear_z + 0.005
	)) {
		discard;
	}
	float target = step(0.5, texture(target_mask, UV).r) * paintable_surface;
	// Every physically traversed mountain-top texel stays visibly painted. The
	// target mask classifies scoreable coverage; it does not erase valid paint.
	float center = texture(paint_mask, UV).r * paintable_surface;
	// PaintSystem only counts texels at or above 0.5. Match that boundary in
	// the visible fill so filtered edge samples cannot form an unscored blue halo.
	float painted = step(0.5, center);
	float wet_core = smoothstep(0.5, 0.72, center);
	float rock_luma = dot(rock_color.rgb, vec3(0.2126, 0.7152, 0.0722));
	// Target Area is a neutral value cue: it remains quieter than blue paint,
	// trajectory, and mechanisms while being identifiable before the first shot.
	vec3 nontarget_rock = mix(rock_color.rgb, vec3(rock_luma), 0.22) * 0.92;
	vec3 target_rock = rock_color.rgb * 1.06;
	vec3 classified_rock = mix(nontarget_rock, target_rock, target);
	// Vertex color is the canonical geometry classification: white is the
	// paintable mountain top and black is the support shell/bottom. A steep but
	// rollable top must not collapse to the same dark value as a vertical skirt.
	vec3 support_rock = mix(shadow_tint.rgb, classified_rock, 0.20 + 0.25 * upwardness);
	vec3 top_rock = classified_rock
		* mix(0.90, 1.04, upwardness)
		* mix(0.965, 1.035, facet_tone);
	vec3 dry_rock = mix(support_rock, top_rock, paintable_surface);
	float paint_luma = dot(paint_color.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 nontarget_paint = mix(paint_color.rgb, vec3(paint_luma), 0.58) * 1.28;
	vec3 painted_color = mix(nontarget_paint, paint_color.rgb, target);
	ALBEDO = mix(dry_rock, painted_color, painted);
	ROUGHNESS = mix(0.88, 0.24, painted);
	SPECULAR = mix(0.32, 0.72, wet_core);
	METALLIC = 0.0;
}
