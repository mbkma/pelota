// A garment of the kit (see KitDesign): its pattern mask (green: the second color, blue: the trim
// color, elsewhere the main color; none: plain) colors the cloth, a tiling knit gives it its weave,
// and an optional normal map (folds, seams) and detail texture (stitching, wear: brightness around
// 0.5) add the garment's own shape. Inside faces (seen through hems and collars) are darker.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D pattern : hint_default_black, filter_linear_mipmap_anisotropic;
uniform vec3 main_color : source_color = vec3(1.0);
uniform vec3 second_color : source_color = vec3(0.1);
uniform vec3 trim_color : source_color = vec3(0.5);
uniform sampler2D detail_texture : hint_default_white, filter_linear_mipmap_anisotropic;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.0;
uniform sampler2D knit_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Knit tiles per UV unit, and how strongly it shows
uniform float knit_scale = 60.0;
uniform float knit_strength : hint_range(0.0, 1.0) = 0.3;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
// Sheen of the fibers at grazing angles
uniform float sheen : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec4 mask = texture(pattern, UV);
	vec3 color = mix(main_color, second_color, mask.g);
	color = mix(color, trim_color, mask.b);
	float detail = texture(detail_texture, UV).r * 2.0;
	color *= mix(1.0, detail, detail_strength);
	vec3 shape = mix(vec3(0.5, 0.5, 1.0), texture(normal_texture, UV).rgb, normal_strength);
	vec3 knit = mix(vec3(0.5, 0.5, 1.0), texture(knit_texture, UV * knit_scale).rgb, knit_strength);
	vec3 n1 = shape * 2.0 - 1.0;
	vec3 n2 = knit * 2.0 - 1.0;
	NORMAL_MAP = normalize(vec3(n1.xy + n2.xy, n1.z * n2.z)) * 0.5 + 0.5;
	ALBEDO = FRONT_FACING ? color : color * 0.55;
	ROUGHNESS = roughness;
	RIM = sheen;
	RIM_TINT = 0.6;
}
