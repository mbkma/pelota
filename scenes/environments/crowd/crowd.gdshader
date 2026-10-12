// A spectator of the crowd, one instance of a MultiMesh. The skeleton is animated on the GPU:
// the bone texture holds, for every frame of every clip, each bone's skinning matrix (three
// texels per bone, one per row of the 3x4 matrix), and the vertex shader skins the vertices with
// it. Each instance plays its idle clip in a loop and can cheer: INSTANCE_CUSTOM holds
//   r: idle clip, g: cheer clip (-1: none), b: time the cheer started, a: look (random in [0, 1)).
// The look sets the idle's phase, the tempo of the cheers (see CrowdCharacter.cheer_tempo) and the
// colors the clothes and hair are tinted with.
// Most spectators turn their head to follow the ball (the look target): the vertices turn around
// the head joint as much as they are skinned to the head (UV2.y), within what a neck can turn.
// A cheer moves the head itself, so the head follows the ball less the more the cheer is blended
// in: the cheer's own head movement is kept, not turned on top of.
// Skinning matrices are kept as their three rows (the first three columns of a mat4, the fourth
// unused), so a point is skinned with dot products: (vec4(point, 1.0) * rows).xyz.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// Clips: first frame in the bone texture, number of frames (FRAME_RATE per second, both ends
// included) and length (s)
const float FRAME_RATE = 30.0;
const int CLIP_COUNT = 9;
uniform float clip_start[CLIP_COUNT];
uniform float clip_frames[CLIP_COUNT];
uniform float clip_length[CLIP_COUNT];
uniform sampler2D bone_texture : filter_nearest, repeat_disable;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
// Time (s) the crowd animates by, set by the crowd every frame
uniform float crowd_time = 0.0;
// Seconds a cheer takes to blend in and out
const float CHEER_BLEND_IN = 0.35;
const float CHEER_BLEND_OUT = 0.6;
// Slowest and fastest tempo a spectator cheers at (see CrowdCharacter.CHEER_TEMPO)
const float CHEER_TEMPO_MIN = 0.85;
const float CHEER_TEMPO_MAX = 1.15;
// Where the spectators look (world space), set by the crowd; the head bone and its joint in the
// model's rest pose
uniform vec3 look_target = vec3(0.0, 1.0, 0.0);
uniform int head_bone = 0;
uniform vec3 head_pivot = vec3(0.0, 1.6, 0.0);
// Whether the spectators follow the ball with their heads (off at low crowd detail)
uniform bool heads_follow = true;
// Share of the spectators that follow the ball, and how far a head turns (rad) sideways and up
// or down
const float FOLLOW_CHANCE = 0.85;
const float MAX_HEAD_YAW = 1.3;
const float MAX_HEAD_PITCH = 0.5;

// Parts of a spectator (see CrowdBaker.Part)
const int PART_TOP = 1;
const int PART_BOTTOM = 2;
const int PART_HAIR = 4;
// Clothes colors; a spectator keeps the original colors of a part with this chance.
const float KEEP_ORIGINAL_CHANCE = 0.3;
const vec3 TOP_COLORS[10] = vec3[](
	vec3(0.95, 0.95, 0.95), vec3(0.15, 0.15, 0.17), vec3(0.12, 0.27, 0.55), vec3(0.2, 0.5, 0.8),
	vec3(0.75, 0.16, 0.14), vec3(0.85, 0.45, 0.1), vec3(0.15, 0.5, 0.25), vec3(0.95, 0.8, 0.25),
	vec3(0.55, 0.2, 0.45), vec3(0.6, 0.75, 0.85));
const vec3 BOTTOM_COLORS[6] = vec3[](
	vec3(0.12, 0.12, 0.14), vec3(0.2, 0.25, 0.4), vec3(0.45, 0.42, 0.38), vec3(0.85, 0.82, 0.75),
	vec3(0.3, 0.22, 0.15), vec3(0.15, 0.2, 0.3));
const vec3 HAIR_COLORS[6] = vec3[](
	vec3(0.08, 0.06, 0.05), vec3(0.2, 0.13, 0.07), vec3(0.4, 0.26, 0.12), vec3(0.6, 0.45, 0.22),
	vec3(0.75, 0.62, 0.4), vec3(0.45, 0.43, 0.42));

varying flat int part;
varying flat float look;

float hash(float value) {
	return fract(sin(value * 78.233) * 43758.5453);
}

// Skinning rows of `bone` at `frame` (a row of the bone texture).
mat4 bone_rows(int bone, int frame) {
	return mat4(
		texelFetch(bone_texture, ivec2(bone * 3, frame), 0),
		texelFetch(bone_texture, ivec2(bone * 3 + 1, frame), 0),
		texelFetch(bone_texture, ivec2(bone * 3 + 2, frame), 0),
		vec4(0.0));
}

// `v` rotated by `angle` (rad) around the unit `axis`.
vec3 rotated(vec3 v, vec3 axis, float angle) {
	return v * cos(angle) + cross(axis, v) * sin(angle) + axis * dot(axis, v) * (1.0 - cos(angle));
}

// Skinning rows of the vertex at `time` (s) into `clip`, between its two nearest frames. Both
// frames are weighted first and blended once: the same as blending each bone, but cheaper.
mat4 skin(int clip, float time, bool loop, ivec4 bones, vec4 weights) {
	// The baked frames span (frames - 1) / FRAME_RATE seconds.
	float frames = clip_frames[clip];
	float span = (frames - 1.0) / FRAME_RATE;
	float position = (loop ? mod(time, span) : clamp(time, 0.0, span)) * FRAME_RATE;
	float frame = min(floor(position), frames - 1.0);
	float next = loop ? mod(frame + 1.0, frames) : min(frame + 1.0, frames - 1.0);
	float blend = position - floor(position);
	int start = int(clip_start[clip]);
	int frame_row = start + int(frame);
	int next_row = start + int(next);
	mat4 current = mat4(0.0);
	mat4 following = mat4(0.0);
	for (int i = 0; i < 4; i++) {
		if (weights[i] <= 0.0) {
			continue;
		}
		current += bone_rows(bones[i], frame_row) * weights[i];
		following += bone_rows(bones[i], next_row) * weights[i];
	}
	return current + (following - current) * blend;
}

// Time (s) into the cheer of an instance with the INSTANCE_CUSTOM `instance_custom`, at its tempo.
float cheer_time(vec4 instance_custom) {
	float tempo = mix(CHEER_TEMPO_MIN, CHEER_TEMPO_MAX, fract(instance_custom.a * 13.0));
	return (crowd_time - instance_custom.b) * tempo;
}

// How far (0 to 1) the cheer of an instance with the INSTANCE_CUSTOM `instance_custom` is blended
// in over its idle.
float cheer_blend(vec4 instance_custom) {
	if (instance_custom.g < 0.0) {
		return 0.0;
	}
	float time = cheer_time(instance_custom);
	float length = clip_length[int(instance_custom.g + 0.5)];
	return smoothstep(0.0, CHEER_BLEND_IN, time)
		* (1.0 - smoothstep(length - CHEER_BLEND_OUT, length, time));
}

// Skinning rows of `bones` weighted by `weights` for an instance with the INSTANCE_CUSTOM
// `instance_custom`: its idle clip, blended into its cheer by `cheer` (see cheer_blend).
mat4 animated(ivec4 bones, vec4 weights, vec4 instance_custom, float cheer) {
	int idle_clip = int(instance_custom.r + 0.5);
	mat4 skinning = skin(idle_clip, crowd_time + instance_custom.a * 97.0, true, bones, weights);
	if (cheer <= 0.0) {
		return skinning;
	}
	int cheer_clip = int(instance_custom.g + 0.5);
	mat4 cheering = skin(cheer_clip, cheer_time(instance_custom), false, bones, weights);
	return skinning + (cheering - skinning) * cheer;
}

void vertex() {
	look = INSTANCE_CUSTOM.a;
	part = int(UV2.x + 0.5);
	float cheer = cheer_blend(INSTANCE_CUSTOM);
	mat4 skinning = animated(ivec4(CUSTOM0 + 0.5), CUSTOM1, INSTANCE_CUSTOM, cheer);
	VERTEX = (vec4(VERTEX, 1.0) * skinning).xyz;
	NORMAL = normalize((vec4(NORMAL, 0.0) * skinning).xyz);

	float head_share = UV2.y * (1.0 - cheer);
	if (heads_follow && head_share > 0.0 && hash(look + 0.7) < FOLLOW_CHANCE) {
		// The head joint and the way the face points, as animated
		mat4 head_skinning = animated(
			ivec4(head_bone, 0, 0, 0), vec4(1.0, 0.0, 0.0, 0.0), INSTANCE_CUSTOM, cheer
		);
		vec3 pivot = (vec4(head_pivot, 1.0) * head_skinning).xyz;
		vec3 face = normalize((vec4(0.0, 0.0, 1.0, 0.0) * head_skinning).xyz);
		// The look target in model space. A spectator's transform only turns and scales evenly, so
		// its inverse is the transposed rotation divided by the squared scale (far cheaper than
		// inverse(), and exact).
		mat3 turn_and_scale = mat3(MODEL_MATRIX);
		vec3 to_target = transpose(turn_and_scale) * (look_target - MODEL_MATRIX[3].xyz)
			/ dot(turn_and_scale[0], turn_and_scale[0]) - pivot;
		float yaw = atan(to_target.x, to_target.z) - atan(face.x, face.z);
		yaw = clamp(mod(yaw + PI, TAU) - PI, -MAX_HEAD_YAW, MAX_HEAD_YAW) * head_share;
		float pitch = atan(to_target.y, length(to_target.xz)) - asin(clamp(face.y, -1.0, 1.0));
		pitch = clamp(pitch, -MAX_HEAD_PITCH, MAX_HEAD_PITCH) * head_share;
		vec3 up = vec3(0.0, 1.0, 0.0);
		vec3 nod_axis = normalize(cross(rotated(face, up, yaw), up));
		VERTEX = pivot + rotated(rotated(VERTEX - pivot, up, yaw), nod_axis, pitch);
		NORMAL = rotated(rotated(NORMAL, up, yaw), nod_axis, pitch);
	}
}

// The texture recolored with `color`, keeping its shading and pattern.
vec3 tinted(vec3 texture_color, vec3 color) {
	float luminance = dot(texture_color, vec3(0.299, 0.587, 0.114));
	return color * clamp(luminance * 2.2, 0.0, 1.4);
}

void fragment() {
	vec4 texture_color = texture(atlas, UV);
	// Cut-out hair and lashes, smoothed by alpha to coverage so they do not shimmer far away
	ALPHA = texture_color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.3;
	ALPHA_TEXTURE_COORDINATE = UV * vec2(textureSize(atlas, 0));
	vec3 color = texture_color.rgb;
	if (part == PART_TOP && hash(look + 0.1) > KEEP_ORIGINAL_CHANCE) {
		color = tinted(color, TOP_COLORS[int(hash(look + 0.2) * 10.0) % 10]);
	} else if (part == PART_BOTTOM && hash(look + 0.3) > KEEP_ORIGINAL_CHANCE) {
		color = tinted(color, BOTTOM_COLORS[int(hash(look + 0.4) * 6.0) % 6]);
	} else if (part == PART_HAIR && hash(look + 0.5) > KEEP_ORIGINAL_CHANCE) {
		color = tinted(color, HAIR_COLORS[int(hash(look + 0.6) * 6.0) % 6]);
	}
	ALBEDO = color;
	ROUGHNESS = 0.85;
}
