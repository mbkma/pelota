// Hair cards: the texture gives the strands (alpha) and their light variation, the color the
// hue, so any hair color works with one dark hair texture. Alpha hashing keeps thin strands
// visible at a distance and needs no depth sorting.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D hair_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 hair_color : source_color = vec3(0.12, 0.08, 0.05);
// Average brightness of the hair texture; strands brighter or darker than it vary the shade.
uniform float texture_brightness = 0.09;

void fragment() {
	vec4 texel = texture(hair_texture, UV);
	float shade = clamp(dot(texel.rgb, vec3(1.0 / 3.0)) / texture_brightness, 0.6, 1.4);
	ALBEDO = hair_color * shade;
	ALPHA = texel.a;
	ALPHA_HASH_SCALE = 1.0;
	ROUGHNESS = 0.6;
}
