// A video board showing the TV picture of the match: the court seen from the main camera behind
// the baseline, the stands beyond it and a score bug, made of glowing LED pixels.
shader_type spatial;
render_mode unshaded, cull_back;

// Brightness of the board
uniform float energy = 1.3;
// LED pixels across the board
instance uniform float pixels_across = 320.0;
// Width / height of the board
instance uniform float aspect = 1.78;

const vec3 FIELD = vec3(0.22, 0.5, 0.3);
const vec3 COURT = vec3(0.17, 0.33, 0.68);
const vec3 LINES = vec3(0.95);
const vec3 WALL = vec3(0.08, 0.18, 0.5);
// Camera of the picture: position, pitch down (radians) and vertical field of view (radians)
const vec3 CAMERA = vec3(0.0, 9.8, 32.2);
const float PITCH = 0.32;
const float FOV = 0.55;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Whether `p` (court coordinates, m) lies on a court line `width` wide
float court_lines(vec2 p, float width) {
	vec2 a = abs(p);
	float on = 0.0;
	// Sidelines (doubles and singles), baselines, service lines, center service line and net
	on += step(abs(a.x - 5.485), width) * step(a.y, 11.885 + width);
	on += step(abs(a.x - 4.115), width) * step(a.y, 11.885 + width);
	on += step(abs(a.y - 11.885), width) * step(a.x, 5.485 + width);
	on += step(abs(a.y - 6.4), width) * step(a.x, 4.115 + width);
	on += step(a.x, width) * step(a.y, 6.4);
	return min(on, 1.0);
}

vec3 picture(vec2 uv) {
	// Ray of the picture's camera through this point, onto the ground
	float tan_half = tan(FOV * 0.5);
	vec3 ray = normalize(vec3((uv.x - 0.5) * 2.0 * tan_half * aspect, (0.5 - uv.y) * 2.0 * tan_half, -1.0));
	ray = vec3(ray.x, ray.y * cos(PITCH) + ray.z * sin(PITCH), ray.z * cos(PITCH) - ray.y * sin(PITCH));
	if (ray.y >= -0.01) {
		return vec3(0.1, 0.12, 0.2);
	}
	vec3 ground = CAMERA + ray * (-CAMERA.y / ray.y);
	vec2 p = ground.xz;
	vec3 color;
	if (abs(p.x) > 12.0 || abs(p.y) > 19.8) {
		// Stands: a wall, then rows of spectators
		float rows = hash(floor(p * vec2(2.0, 1.5)));
		color = mix(vec3(0.12, 0.2, 0.45), vec3(0.75, 0.6, 0.5), rows * 0.6);
		if (abs(p.y) < 21.0 && abs(p.x) < 13.0) {
			color = WALL;
		}
	} else if (abs(p.x) < 5.485 && abs(p.y) < 11.885) {
		color = COURT;
	} else {
		color = FIELD;
	}
	color = mix(color, LINES, court_lines(p, 0.09));
	// The net
	if (abs(p.y) < 0.12 && abs(p.x) < 6.4) {
		color = vec3(0.05);
	}
	return color;
}

void fragment() {
	vec2 pixel = floor(UV * vec2(pixels_across, pixels_across / aspect));
	vec2 uv = (pixel + 0.5) / vec2(pixels_across, pixels_across / aspect);
	vec3 color = picture(uv);
	// Score bug in the top left corner
	if (uv.x > 0.04 && uv.x < 0.3 && uv.y > 0.06 && uv.y < 0.2) {
		color = vec3(0.04, 0.08, 0.25);
		if (uv.x > 0.06 && uv.x < 0.2 && (abs(uv.y - 0.1) < 0.012 || abs(uv.y - 0.16) < 0.012)) {
			color = vec3(0.9);
		}
		if (uv.x > 0.24 && uv.x < 0.28 && uv.y > 0.08 && uv.y < 0.18) {
			color = vec3(0.95, 0.8, 0.2);
		}
	}
	// Each LED is a soft dot
	vec2 cell = fract(UV * vec2(pixels_across, pixels_across / aspect)) - 0.5;
	float led = 1.0 - smoothstep(0.25, 0.5, length(cell)) * 0.45;
	ALBEDO = color * led * energy;
}
