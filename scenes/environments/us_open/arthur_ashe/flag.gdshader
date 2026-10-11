// The flag of the United States hanging from the roof, rippling gently.
shader_type spatial;
render_mode cull_disabled;

const vec3 RED = vec3(0.6, 0.06, 0.1);
const vec3 WHITE = vec3(0.92, 0.92, 0.9);
const vec3 BLUE = vec3(0.1, 0.12, 0.32);

void vertex() {
	// Ripples run down the flag, growing from the top edge it hangs from.
	VERTEX.z += sin(UV.y * 9.0 - TIME * 1.6 + UV.x * 2.0) * 0.12 * UV.y;
}

void fragment() {
	// Hanging, the stripes run down and the canton is at the top left.
	float stripe = floor(UV.x * 13.0);
	vec3 color = mod(stripe, 2.0) < 0.5 ? RED : WHITE;
	if (UV.x < 7.0 / 13.0 && UV.y < 0.4) {
		color = BLUE;
		vec2 star = fract(vec2(UV.x * 13.0 / 7.0 * 9.0, UV.y / 0.4 * 11.0)) - 0.5;
		color = mix(color, WHITE, 1.0 - smoothstep(0.15, 0.25, length(star)));
	}
	ALBEDO = color;
	ROUGHNESS = 0.8;
}
