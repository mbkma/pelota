// Sweat soaking through a shirt: darker patches on the chest and back, under the arms and around
// the collar, drawn over the shirt (as the next pass of its material). They have their full size
// from the start and soak through more and more with `sweat`, and they have uneven edges.
// Positions are in the shirt mesh's space in its rest pose (meters, y up, the front facing +z),
// scaled to the default body's height, which the body importer stores per vertex in CUSTOM0, so
// the patches stay on the cloth as the player moves (the vertex position itself is already posed).
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_back, shadows_disabled;

// How much the player sweats, in [0, 1]
uniform float sweat : hint_range(0.0, 1.0) = 0.0;
// Color the shirt is multiplied with where it is fully soaked
uniform vec3 soaked_tint : source_color = vec3(0.66, 0.68, 0.74);

varying vec3 shirt_position;

void vertex() {
	shirt_position = CUSTOM0.xyz;
}

// 1 where `position` is inside an ellipsoid patch around `center` with `radius`, fading out at its
// edge.
float patch(vec3 position, vec3 center, vec3 radius) {
	return 1.0 - smoothstep(0.55, 1.0, length((position - center) / radius));
}

void fragment() {
	vec3 mirrored = vec3(abs(shirt_position.x), shirt_position.yz);
	float soaked = max(
		// Chest and the back along the spine
		max(patch(shirt_position, vec3(0.0, 1.4, 0.14), vec3(0.13, 0.15, 0.13)),
			patch(shirt_position, vec3(0.0, 1.32, -0.12), vec3(0.11, 0.22, 0.12))),
		// A thin band around the collar, and under the arms
		max(patch(shirt_position, vec3(0.0, 1.57, 0.03), vec3(0.14, 0.03, 0.18)),
			patch(mirrored, vec3(0.17, 1.31, 0.03), vec3(0.07, 0.1, 0.13)))
	);
	// Uneven edges where the wet cloth spreads
	float wobble = sin(shirt_position.x * 47.0 + shirt_position.y * 13.0)
		* sin(shirt_position.y * 39.0 - shirt_position.z * 21.0);
	soaked = clamp(soaked + wobble * 0.15 * soaked * (1.0 - soaked) * 4.0, 0.0, 1.0);
	ALBEDO = mix(vec3(1.0), soaked_tint, soaked * sweat);
}
