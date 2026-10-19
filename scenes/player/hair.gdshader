// Hair cards (also eyebrows and eyelashes): the texture gives the strands (alpha) and their light
// variation, the color the hue, so any hair color works with any hair texture. Strands brighter or
// darker than the texture's average (its smallest mip level) vary the shade. Alpha hashing keeps
// thin strands visible at a distance and needs no depth sorting.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D hair_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 hair_color : source_color = vec3(0.12, 0.08, 0.05);
uniform float roughness : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	vec4 texel = texture(hair_texture, UV);
	vec4 average = textureLod(hair_texture, vec2(0.5), 16.0);
	float brightness = max(dot(average.rgb, vec3(1.0 / 3.0)), 0.02);
	float shade = clamp(dot(texel.rgb, vec3(1.0 / 3.0)) / brightness, 0.6, 1.4);
	ALBEDO = hair_color * shade;
	ALPHA = texel.a;
	ALPHA_HASH_SCALE = 1.0;
	ROUGHNESS = roughness;
}
