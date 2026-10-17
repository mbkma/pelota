// The painted acrylic of a hard court (the court, its lines and the surround around it): sand
// mixed into the paint gives it a fine grain, the paint's tone varies a little over the court,
// and where the players run most, behind the baselines, the paint is scuffed and polished by
// their shoes, which leave dark rubber marks from sliding sideways. Everything is placed by the
// world position, so it runs on across the court, its lines and the surround. Flat surfaces only
// (the grain's normals are bent around the up axis).
shader_type spatial;

uniform vec3 paint_color : source_color = vec3(0.125, 0.195, 0.375);
uniform float roughness : hint_range(0.0, 1.0) = 0.78;
// Grain of the sand in the paint: its normal and roughness maps, their size (m) and strength
uniform sampler2D grain_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grain_roughness : hint_roughness_gray, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float grain_size = 0.6;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.35;
uniform float grain_roughness_variation : hint_range(0.0, 1.0) = 0.12;
// Uneven paint: a gray texture (read as data, around 0.5) whose variation (share of the
// brightness) over `tone_size` (m)
uniform sampler2D tone_texture : filter_linear_mipmap, repeat_enable;
uniform float tone_size = 9.0;
uniform float tone_variation : hint_range(0.0, 0.3) = 0.06;
// Worn areas behind each baseline: their middle (|z|, m) and half size (x, z), how far the
// paint is faded (paler and grayer) there, polished smoother, and the rubber marks of the shoes
uniform float wear_center_z = 12.4;
uniform vec2 wear_half_size = vec2(4.8, 2.6);
uniform float wear_fade : hint_range(0.0, 1.0) = 0.6;
uniform float wear_polish : hint_range(0.0, 0.5) = 0.18;
uniform float rubber_marks : hint_range(0.0, 1.0) = 0.5;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// How worn the paint is at `p` (0 to 1): most behind the middle of each baseline, in patches.
float wear(vec2 p) {
	vec2 offset = vec2(p.x, abs(p.y) - wear_center_z) / wear_half_size;
	float patches = texture(tone_texture, p / 2.5).r * 2.0 - 0.4;
	return clamp((1.0 - smoothstep(0.1, 1.0, length(offset))) * patches, 0.0, 1.0);
}

void fragment() {
	vec2 p = world_position.xz;
	vec2 grain_uv = p / grain_size;
	float tone = texture(tone_texture, p / tone_size).r - 0.5;
	float worn = wear(p);
	// Shoe marks run across the court (players slide sideways): the texture stretched along x
	float streaks = texture(tone_texture, vec2(p.x * 0.35, p.y * 3.0)).r;
	float marks = smoothstep(0.5, 0.7, streaks) * worn * rubber_marks;

	vec3 color = paint_color * COLOR.rgb * (1.0 + tone * tone_variation * 2.0);
	// Scuffed paint: grayer, and paler from the dust of the shoes' rubber
	vec3 faded = mix(color, vec3(dot(color, vec3(0.3, 0.59, 0.11))), 0.5) + vec3(0.035);
	color = mix(color, faded, worn * wear_fade);
	color = mix(color, vec3(0.012), marks);
	ALBEDO = color;

	float grain = texture(grain_roughness, grain_uv).r - 0.5;
	ROUGHNESS = clamp(roughness + grain * grain_roughness_variation - worn * wear_polish + marks * 0.1, 0.05, 1.0);

	// The grain's normal map lies in the xz plane: bend the up axis by it.
	vec2 bend = (texture(grain_normal, grain_uv).rg * 2.0 - 1.0) * grain_strength * (1.0 - worn * 0.5);
	vec3 world_normal = normalize(vec3(bend.x, 1.0, -bend.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
}
