// Red brick of the stadium's facade, laid in running bond. UV is the position on the wall in
// meters (along the wall, up).
shader_type spatial;

uniform vec3 brick_color : source_color = vec3(0.5, 0.2, 0.14);
uniform vec3 mortar_color : source_color = vec3(0.62, 0.58, 0.52);
// Brick size with its joint (m)
uniform vec2 brick_size = vec2(0.42, 0.14);
uniform float joint = 0.015;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 position = UV / brick_size;
	float row = floor(position.y);
	position.x += mod(row, 2.0) * 0.5;
	vec2 brick = floor(position);
	vec2 inside = fract(position) * brick_size;
	// Joints, blurred where they get smaller than a pixel
	vec2 blur = fwidth(UV) * 1.5;
	vec2 edge = smoothstep(vec2(joint) - blur, vec2(joint) + blur, min(inside, brick_size - inside) * 2.0);
	float is_brick = edge.x * edge.y;
	vec3 color = brick_color * (0.82 + 0.3 * hash(brick));
	ALBEDO = mix(mortar_color, color, mix(0.7, is_brick, clamp(1.0 - blur.y * 20.0, 0.0, 1.0)));
	ROUGHNESS = 0.9;
}
