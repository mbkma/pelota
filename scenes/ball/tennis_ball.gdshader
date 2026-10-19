// Tennis ball: optic yellow felt with a white rubber seam and a printed logo. The seam follows the
// classic tennis ball curve on the unit sphere, (a cos t + b cos 3t, a sin t - b sin 3t,
// 2 sqrt(ab) sin 2t) with a + b = 1; the panels' waists lie at +z and -z, the logo is printed on
// the waist at +z. Fuzz shells (shell > 0) draw the felt's loose fibers around the ball.
shader_type spatial;
render_mode cull_back;

uniform vec3 felt_color : source_color = vec3(0.7, 0.79, 0.07);
uniform vec3 seam_color : source_color = vec3(0.9, 0.88, 0.82);
// Logo printed on the panel at +z (transparent where there is no ink)
uniform sampler2D logo : source_color, filter_linear_mipmap, repeat_disable;
// Where the logo lies on the panel, in ball radii: its center and half its size
uniform vec2 logo_center = vec2(0.0, 0.05);
uniform vec2 logo_half_size = vec2(0.64, 0.384);
// Seam curve's a (larger: wider panel waists) and the seam's half width (rad)
uniform float seam_shape : hint_range(0.5, 0.95) = 0.8;
uniform float seam_half_width : hint_range(0.01, 0.2) = 0.045;
// Depth of the felt's bumps (m) and the scale of its tufts (per ball radius)
uniform float bump_depth = 0.0004;
uniform float fiber_scale = 30.0;
// Fuzz shell: how far out this shell lies (0: the ball itself) as a share of the fuzz's length
// (ball radii), and how much of the felt grows fibers that far out
uniform float shell : hint_range(0.0, 1.0) = 0.0;
uniform float fuzz_length = 0.05;
uniform float fuzz_coverage : hint_range(0.0, 1.0) = 0.45;

varying vec3 ball_dir;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3)) * 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float sum = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		sum += amplitude * value_noise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		amplitude *= 0.5;
	}
	return sum;
}

vec3 seam_point(float t) {
	float a = seam_shape;
	float b = 1.0 - a;
	return vec3(a * cos(t) + b * cos(3.0 * t), a * sin(t) - b * sin(3.0 * t),
			2.0 * sqrt(a * b) * sin(2.0 * t));
}

// Angle (rad) between a direction and the nearest point of the seam
float seam_distance(vec3 dir) {
	const int SAMPLES = 48;
	float best_t = 0.0;
	float best = -2.0;
	for (int i = 0; i < SAMPLES; i++) {
		float t = float(i) * TAU / float(SAMPLES);
		float d = dot(dir, seam_point(t));
		if (d > best) {
			best = d;
			best_t = t;
		}
	}
	float step = TAU / float(SAMPLES);
	for (int i = 0; i < 8; i++) {
		step *= 0.5;
		float before = dot(dir, seam_point(best_t - step));
		float after = dot(dir, seam_point(best_t + step));
		if (before > best) {
			best = before;
			best_t -= step;
		} else if (after > best) {
			best = after;
			best_t += step;
		}
	}
	return acos(clamp(best, -1.0, 1.0));
}

// The logo's ink (color and coverage) at a direction
vec4 logo_ink(vec3 dir) {
	if (dir.z < 0.3) {
		return vec4(0.0);
	}
	// The seam's arcs pass above and below the logo
	vec3 up = normalize(vec3(1.0, 1.0, 0.0));
	vec3 right = normalize(vec3(1.0, -1.0, 0.0));
	vec2 on_panel = vec2(dot(dir, right), dot(dir, up));
	vec2 uv = (on_panel - logo_center) / (2.0 * logo_half_size) + 0.5;
	uv.y = 1.0 - uv.y;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		return vec4(0.0);
	}
	return texture(logo, uv);
}

void vertex() {
	ball_dir = normalize(VERTEX);
	VERTEX *= 1.0 + shell * fuzz_length;
}

void fragment() {
	vec3 dir = normalize(ball_dir);
	float fibers = fbm(dir * fiber_scale);
	float seam = seam_distance(dir);
	// The felt's edge along the seam is ragged
	float edge = seam_half_width + (fbm(dir * fiber_scale * 0.5) - 0.5) * 0.02;
	float on_seam = 1.0 - smoothstep(edge - 0.006, edge + 0.006, seam);
	vec4 ink = logo_ink(dir);
	// Ink soaks into the felt unevenly at its edges
	ink.a = smoothstep(0.3, 0.7, ink.a + (fibers - 0.5) * 0.5);

	if (shell > 0.0) {
		// Loose fibers: a share of the felt reaches out this far, none over the bare seam
		float reach = value_noise(dir * fiber_scale * 1.7 + vec3(shell * 7.0));
		if (reach < 1.0 - fuzz_coverage * (1.0 - shell) || seam < edge + 0.02) {
			discard;
		}
		vec3 fiber = felt_color * (1.05 + 0.2 * reach);
		ALBEDO = mix(fiber, ink.rgb, ink.a);
		ROUGHNESS = 1.0;
		RIM = 0.6;
		RIM_TINT = 0.8;
	} else {
		vec3 felt = felt_color * (0.72 + 0.5 * fibers);
		// The seam lies in a groove: a shadow where the felt overhangs it
		float groove = smoothstep(0.0, edge, seam);
		vec3 rubber = seam_color * mix(1.0, 0.72, pow(groove, 4.0));
		ALBEDO = mix(mix(felt, ink.rgb, ink.a), rubber, on_seam);
		ROUGHNESS = mix(1.0, 0.55, on_seam);
		RIM = 0.45 * (1.0 - on_seam);
		RIM_TINT = 0.8;

		// Bumps: the felt's tufts, the groove of the seam
		float height = bump_depth * (fibers - 1.5 * on_seam * (1.0 - groove * 0.5));
		vec3 dpdx = dFdx(VERTEX);
		vec3 dpdy = dFdy(VERTEX);
		vec3 r1 = cross(dpdy, NORMAL);
		vec3 r2 = cross(NORMAL, dpdx);
		float det = dot(dpdx, r1);
		vec3 gradient = sign(det) * (dFdx(height) * r1 + dFdy(height) * r2);
		NORMAL = normalize(abs(det) * NORMAL - gradient);
	}
}
