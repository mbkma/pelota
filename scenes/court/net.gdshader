// The net's mesh: black cords in a square grid, see-through between them. UV is the position on
// the net in meters. Where the cords get finer than a pixel the net fades to its average
// density, so it does not shimmer from far away.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec3 cord_color : source_color = vec3(0.03, 0.03, 0.035);
// Size of a mesh square and thickness of a cord (m)
uniform float cell = 0.045;
uniform float cord = 0.003;

void fragment() {
	vec2 grid = UV / cell;
	vec2 width = fwidth(grid);
	// Distance to the nearest cord, in pixels
	vec2 to_cord = abs(fract(grid - 0.5) - 0.5) / max(width, vec2(1e-4));
	float thickness = cord / cell;
	float line = 1.0 - clamp(min(to_cord.x, to_cord.y) - thickness / max(width.x, 1e-4) * 0.5, 0.0, 1.0);
	float density = 1.0 - (1.0 - thickness) * (1.0 - thickness);
	ALPHA = mix(line, density * 1.4, smoothstep(0.25, 0.8, max(width.x, width.y)));
	ALBEDO = cord_color;
	ROUGHNESS = 0.8;
}
