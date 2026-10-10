// Sweat soaking through a shirt: darker patches on the chest and back, under the arms and around
// the collar, drawn over the shirt (as the next pass of its material). They grow with `sweat` and
// have uneven edges. Positions are in the shirt mesh's space (meters, y up).
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_back, shadows_disabled;

// How much the player sweats, in [0, 1]
uniform float sweat : hint_range(0.0, 1.0) = 0.0;
// Color the shirt is multiplied with where it is soaked
uniform vec3 soaked_tint : source_color = vec3(0.66, 0.68, 0.74);
// Share of their full size the patches have when the sweat begins
uniform float start_size = 0.35;

varying vec3 shirt_position;

void vertex() {
	shirt_position = VERTEX;
}

// 1 inside an ellipsoid patch around `center` with `radius`, fading out at its edge.
float patch(vec3 center, vec3 radius) {
	float size = mix(start_size, 1.0, sweat);
	return 1.0 - smoothstep(0.55, 1.0, length((shirt_position - center) / (radius * size)));
}

void fragment() {
	vec3 mirrored = vec3(abs(shirt_position.x), shirt_position.yz);
	float soaked = max(
		// Chest (the front faces -z) and the back along the spine
		max(patch(vec3(0.0, 1.42, -0.1), vec3(0.13, 0.15, 0.13)),
			patch(vec3(0.0, 1.34, 0.15), vec3(0.11, 0.22, 0.12))),
		// A thin band around the collar, and under the arms
		max(patch(vec3(0.0, 1.6, 0.03), vec3(0.14, 0.03, 0.18)),
			1.0 - smoothstep(0.55, 1.0, length((mirrored - vec3(0.17, 1.33, 0.03))
				/ (vec3(0.07, 0.1, 0.13) * mix(start_size, 1.0, sweat)))))
	);
	// Uneven edges where the wet cloth spreads
	float wobble = sin(shirt_position.x * 47.0 + shirt_position.y * 13.0)
		* sin(shirt_position.y * 39.0 - shirt_position.z * 21.0);
	soaked = clamp(soaked + wobble * 0.15 * soaked * (1.0 - soaked) * 4.0, 0.0, 1.0);
	ALBEDO = mix(vec3(1.0), soaked_tint, soaked * smoothstep(0.0, 0.25, sweat));
}
