// Front element of a camera lens: dark glass with a multi-coating. It mirrors its surroundings
// tinted by the coating, whose color shifts with the viewing angle (green face on, purple to
// amber at grazing angles), and shows the faint rings of the lens elements behind it.
shader_type spatial;
render_mode cull_back;

uniform vec3 glass_color : source_color = vec3(0.01, 0.012, 0.02);
uniform vec3 coating_face : source_color = vec3(0.18, 0.55, 0.32);
uniform vec3 coating_side : source_color = vec3(0.55, 0.22, 0.65);
uniform vec3 coating_edge : source_color = vec3(0.8, 0.55, 0.25);
// How strongly the coating tints the reflections
uniform float coating_strength : hint_range(0.0, 1.0) = 0.6;
// Radius (object space) of the glass and number of element rings seen through it
uniform float glass_radius = 0.072;
uniform float element_rings = 4.0;

varying vec2 lens_offset;

void vertex() {
	lens_offset = VERTEX.xz / glass_radius;
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 4.0);
	vec3 coating = mix(coating_side, coating_face, smoothstep(0.35, 0.95, facing));
	coating = mix(coating, coating_edge, smoothstep(0.75, 1.0, 1.0 - facing));

	// Elements deeper in the lens show as faint, sharp-edged rings.
	float radius = length(lens_offset);
	float rings = smoothstep(0.92, 1.0, fract(radius * element_rings)) * (1.0 - radius);

	// The reflections take the coating's color: faint face on, full at grazing angles.
	ALBEDO = glass_color + coating * mix(coating_strength, 1.0, fresnel);
	ALBEDO += coating * rings * 0.35;
	METALLIC = 0.9;
	ROUGHNESS = 0.03;
	SPECULAR = 0.9;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.02;
}
