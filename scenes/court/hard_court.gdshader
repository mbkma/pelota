// The painted acrylic of a hard court (the court, its lines and the surround around it): sand
// mixed into the paint gives it a fine grain, the paint's tone varies softly over the court,
// and the players' shoes leave thin curved scuff marks all over it, paler than the paint and a
// little polished. Everything
// is placed by the world position, so it runs on across the court, its lines and the surround;
// every texture is read twice, turned and scaled differently, so it does not show repeating.
// Flat surfaces only (the grain's normals are bent around the up axis).
shader_type spatial;

uniform vec3 paint_color : source_color = vec3(0.125, 0.195, 0.375);
uniform float roughness : hint_range(0.0, 1.0) = 0.78;
// Grain of the sand in the paint: its normal and roughness maps, their size (m) and strength
uniform sampler2D grain_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grain_roughness : hint_roughness_gray, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float grain_size = 0.6;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.35;
uniform float grain_roughness_variation : hint_range(0.0, 1.0) = 0.12;
// Uneven paint: a seamless noise (0 to 1), the size (m) of its large and small blotches, and
// how much they vary the paint's brightness
uniform sampler2D tone_noise : filter_linear_mipmap, repeat_enable;
uniform vec2 tone_size = vec2(18.0, 3.1);
uniform vec2 tone_variation = vec2(0.07, 0.035);
// Scuff marks (see CourtScuffsBuilder): the size (m) the texture covers, how many of its marks
// show, and how they change the paint: how much grayer, how much lighter (darker below 0) and
// smoother
uniform sampler2D scuffs : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float scuff_size = 6.0;
uniform float scuff_amount : hint_range(0.0, 1.0) = 0.5;
uniform float scuff_strength : hint_range(0.0, 1.0) = 0.35;
uniform float scuff_desaturation : hint_range(0.0, 1.0) = 0.5;
uniform float scuff_lift : hint_range(-0.3, 0.3) = 0.06;
uniform float scuff_polish : hint_range(0.0, 0.5) = 0.12;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// `p` turned by `angle`
vec2 turned(vec2 p, float angle) {
	return mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * p;
}

void fragment() {
	vec2 p = world_position.xz;
	vec2 q = turned(p, 0.71) + vec2(3.7, 1.3);

	float large = texture(tone_noise, p / tone_size.x).r;
	float small = texture(tone_noise, q / tone_size.y).r;
	float tone = (large - 0.5) * tone_variation.x + (small - 0.5) * tone_variation.y;

	// The two readings of the scuffs take turns in blotches, so the marks keep their density.
	float marks_a = texture(scuffs, p / scuff_size).r;
	float marks_b = texture(scuffs, q / (scuff_size * 0.77)).r;
	float marks = mix(marks_a, marks_b, smoothstep(0.42, 0.58, small)) * scuff_amount;

	vec3 color = paint_color * COLOR.rgb * (1.0 + tone * 2.0);
	vec3 gray = vec3(dot(color, vec3(0.3, 0.59, 0.11)));
	vec3 scuffed = mix(color, gray, scuff_desaturation) + vec3(scuff_lift);
	ALBEDO = mix(color, max(scuffed, vec3(0.0)), marks * scuff_strength);

	vec2 grain_uv = p / grain_size;
	vec2 grain_uv2 = q / (grain_size * 0.83);
	float grain = (texture(grain_roughness, grain_uv).r + texture(grain_roughness, grain_uv2).r) * 0.5 - 0.5;
	ROUGHNESS = clamp(roughness + grain * grain_roughness_variation - marks * scuff_polish, 0.05, 1.0);

	// The grain's normal maps lie in the xz plane: bend the up axis by them. The second one is
	// turned, so its bend turns back.
	vec2 bend_a = texture(grain_normal, grain_uv).rg * 2.0 - 1.0;
	vec2 bend_b = turned(texture(grain_normal, grain_uv2).rg * 2.0 - 1.0, -0.71);
	vec2 bend = (bend_a + bend_b) * 0.5 * grain_strength * (1.0 - marks * 0.6);
	vec3 world_normal = normalize(vec3(bend.x, 1.0, -bend.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
}
