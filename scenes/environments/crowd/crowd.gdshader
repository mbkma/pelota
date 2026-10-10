// A spectator of the crowd, one instance of a MultiMesh. The skeleton is animated on the GPU:
// the bone texture holds, for every frame of every clip, each bone's skinning matrix (three
// texels per bone, one per row of the 3x4 matrix), and the vertex shader skins the vertices with
// it. Each instance plays its idle clip in a loop and can cheer: INSTANCE_CUSTOM holds
//   r: idle clip, g: cheer clip (-1: none), b: time the cheer started, a: look (random in [0, 1)).
// The look sets the idle's phase and the colors the clothes and hair are tinted with.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// Clips: first frame in the bone texture, number of frames (FRAME_RATE per second, both ends
// included) and length (s)
const float FRAME_RATE = 30.0;
const int CLIP_COUNT = 6;
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

// Skinning matrix of `bone` at `frame` (a row of the bone texture).
mat4 bone_matrix(int bone, int frame) {
	vec4 row0 = texelFetch(bone_texture, ivec2(bone * 3, frame), 0);
	vec4 row1 = texelFetch(bone_texture, ivec2(bone * 3 + 1, frame), 0);
	vec4 row2 = texelFetch(bone_texture, ivec2(bone * 3 + 2, frame), 0);
	return transpose(mat4(row0, row1, row2, vec4(0.0, 0.0, 0.0, 1.0)));
}

// Skinning matrix of the vertex at `time` (s) into `clip`, between its two nearest frames.
mat4 skin(int clip, float time, bool loop, ivec4 bones, vec4 weights) {
	// The baked frames span (frames - 1) / FRAME_RATE seconds.
	float frames = clip_frames[clip];
	float span = (frames - 1.0) / FRAME_RATE;
	float position = (loop ? mod(time, span) : clamp(time, 0.0, span)) * FRAME_RATE;
	float frame = min(floor(position), frames - 1.0);
	float next = loop ? mod(frame + 1.0, frames) : min(frame + 1.0, frames - 1.0);
	float blend = position - floor(position);
	int start = int(clip_start[clip]);
	mat4 result = mat4(0.0);
	for (int i = 0; i < 4; i++) {
		if (weights[i] <= 0.0) {
			continue;
		}
		mat4 a = bone_matrix(bones[i], start + int(frame));
		mat4 b = bone_matrix(bones[i], start + int(next));
		result += (a + (b - a) * blend) * weights[i];
	}
	return result;
}

void vertex() {
	ivec4 bones = ivec4(CUSTOM0 + 0.5);
	vec4 weights = CUSTOM1;
	int idle_clip = int(INSTANCE_CUSTOM.r + 0.5);
	int cheer_clip = int(INSTANCE_CUSTOM.g + 0.5);
	look = INSTANCE_CUSTOM.a;
	part = int(UV2.x + 0.5);

	float phase = look * 97.0;
	mat4 skinning = skin(idle_clip, crowd_time + phase, true, bones, weights);
	if (INSTANCE_CUSTOM.g >= 0.0) {
		float cheer_time = crowd_time - INSTANCE_CUSTOM.b;
		float cheer_length = clip_length[cheer_clip];
		float cheer = smoothstep(0.0, CHEER_BLEND_IN, cheer_time)
			* (1.0 - smoothstep(cheer_length - CHEER_BLEND_OUT, cheer_length, cheer_time));
		if (cheer > 0.0) {
			mat4 cheering = skin(cheer_clip, cheer_time, false, bones, weights);
			skinning = skinning + (cheering - skinning) * cheer;
		}
	}
	VERTEX = (skinning * vec4(VERTEX, 1.0)).xyz;
	NORMAL = normalize(mat3(skinning) * NORMAL);
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
