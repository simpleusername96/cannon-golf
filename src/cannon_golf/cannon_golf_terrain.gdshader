shader_type spatial;
render_mode depth_draw_opaque, cull_disabled;

uniform vec4 rock_color : source_color = vec4(0.35, 0.40, 0.38, 1.0);
uniform vec4 accent_color : source_color = vec4(0.28, 0.33, 0.31, 1.0);
uniform vec4 goal_color : source_color = vec4(0.145, 0.518, 1.0, 1.0);
uniform vec4 goal_regions[6];
uniform int goal_region_count = 0;

varying float terrain_tone;
varying float upwardness;
varying float goal_tone;

void vertex() {
	terrain_tone = COLOR.g;
	upwardness = clamp(NORMAL.y, 0.0, 1.0);
	goal_tone = 0.0;
	for (int index = 0; index < 6; index++) {
		if (index >= goal_region_count) {
			break;
		}
		vec4 region = goal_regions[index];
		float distance_to_goal = distance(VERTEX.xz, region.xy);
		goal_tone = max(
			goal_tone,
			1.0 - smoothstep(region.z * 0.82, region.z, distance_to_goal)
		);
	}
}

void fragment() {
	vec3 terrain = mix(accent_color.rgb, rock_color.rgb, 0.45 + terrain_tone * 0.4);
	terrain *= mix(0.88, 1.06, upwardness) * mix(0.95, 1.04, terrain_tone);
	vec3 marked_goal = goal_color.rgb * mix(0.88, 1.05, terrain_tone);
	ALBEDO = mix(terrain, marked_goal, goal_tone * 0.88);
	ROUGHNESS = 0.94;
	SPECULAR = 0.18;
	METALLIC = 0.0;
}
