// Skin: the skin tone texture (tinted), fine pores from a tiling normal map, and sweat that makes
// it wet and shiny (see Model.set_sweat). No subsurface scattering: Godot's screen-space blur pulls
// what is behind thin limbs (e.g. a court line behind the legs) into the skin.
shader_type spatial;

uniform sampler2D skin_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 tint : source_color = vec3(1.0);
uniform sampler2D pores_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Pore tiles per UV unit, and how strongly they show
uniform float pore_scale = 24.0;
uniform float pore_strength : hint_range(0.0, 1.0) = 0.35;
// Dry skin is fairly rough and reflects less than most dielectrics (F0 about 0.028)
uniform float roughness : hint_range(0.0, 1.0) = 0.7;
uniform float specular : hint_range(0.0, 1.0) = 0.35;
// How much the player sweats, in [0, 1]: the skin gets smoother and gets a wet film
uniform float sweat : hint_range(0.0, 1.0) = 0.0;
uniform float wet_roughness : hint_range(0.0, 1.0) = 0.25;
uniform float wet_clearcoat : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	ALBEDO = texture(skin_texture, UV).rgb * tint;
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), texture(pores_texture, UV * pore_scale).rgb, pore_strength);
	ROUGHNESS = mix(roughness, wet_roughness, sweat);
	SPECULAR = specular;
	CLEARCOAT = wet_clearcoat * sweat;
	CLEARCOAT_ROUGHNESS = 0.2;
}
