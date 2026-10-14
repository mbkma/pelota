## Post-import script for the Mixamo locomotion clips. Runs after the import has retargeted the
## clip to the GeneralSkeleton (see mixamo_bone_map.tres) and saves it as an in-place player
## animation: root motion removed, the bones Mixamo does not animate (face, helper bones) held in
## the idle pose, the racket held in the right hand (see _carry_racket), and resampled to
## one gait cycle of CYCLE_LENGTH that starts as the left foot touches down. All locomotion clips
## are so in phase and can be blended in sync (see PlayerAnimator); each keeps its real cycle time
## and running speed as metadata.
@tool
extends EditorScenePostImport

## Player animation saved for each source file.
const ANIMATIONS: Dictionary[String, String] = {
	"walking.fbx": "walk",
	"running.fbx": "run",
	"left_strafe.fbx": "strafe_left",
	"right_strafe.fbx": "strafe_right",
	"left_strafe_walking.fbx": "strafe_walk_left",
	"right_strafe_walking.fbx": "strafe_walk_right",
}
## Player animation played backward saved for source files that have one.
const REVERSED_ANIMATIONS: Dictionary[String, String] = {
	"walking.fbx": "walk_backward",
	"running.fbx": "run_backward",
}
## Length (s) of the saved gait cycles, and the key rate (per second of the real cycle) they are
## resampled at
const CYCLE_LENGTH: float = 1.0
const RESAMPLE_RATE: float = 30.0
## Samples per cycle searched for the touchdown, and the foot height (share of its range from the
## lowest point) below which the foot counts as down
const TOUCHDOWN_SAMPLES: int = 120
const TOUCHDOWN_HEIGHT: float = 0.2
const TOUCHDOWN_BONE: StringName = &"LeftFoot"
## Metadata of the saved clips: real cycle time (s) and running speed (m/s)
const CYCLE_TIME_META: StringName = &"cycle_time"
const TRAVEL_SPEED_META: StringName = &"travel_speed"
const OUTPUT_DIR: String = "res://scenes/player/animations/"
const SOURCE_ANIMATION: StringName = &"mixamo_com"
const HIPS_PATH: NodePath = ^"%GeneralSkeleton:Hips"
## Pose the bones Mixamo does not animate (face, helper bones) and the racket grip are held in.
const HOLD_POSE_ANIMATION: String = "res://scenes/player/animations/idle.tres"
## Bones of the hands: the fingers below them follow Mixamo, except those of the racket hand.
const HAND_BONES: Array[StringName] = [&"LeftHand", &"RightHand"]
## Hand holding the racket: the fingers keep the idle pose's grip around the handle. Its wrist
## turns the racket to point the way the chest faces, CARRY_PITCH above the horizontal and its
## face upright, at the middle of the arm swing. The racket swings with the arm, the wrist taking
## up CARRY_STEADINESS of the swing so the racket head stays clear of the legs.
const RACKET_HAND_BONE: StringName = &"RightHand"
const RACKET_BONE: StringName = &"RacketGrip"
const CHEST_BONE: StringName = &"UpperChest"
const CARRY_PITCH: float = deg_to_rad(15.0)
const CARRY_STEADINESS: float = 0.5
## Samples over the clip the middle of the arm swing is averaged from
const CARRY_SAMPLES: int = 60
## Player model whose (default body's) skeleton rest pose the animations are matched to, holding
## the racket.
const TARGET_MODEL: String = "res://scenes/player/model.tscn"
## Bones each bone points to, in both rigs: the first sets the bone's direction, the second (if
## any) its twist around it. Animated bones not listed keep their bend relative to the rest pose.
## The hands point to their fingers, which hang off palm bones in the target rig only.
const BONE_TAILS: Dictionary[StringName, Array] = {
	&"Hips": [&"Spine"],
	&"Spine": [&"Chest"],
	&"Chest": [&"UpperChest"],
	&"UpperChest": [&"Neck"],
	&"Neck": [&"Head"],
	&"LeftShoulder": [&"LeftUpperArm"],
	&"LeftUpperArm": [&"LeftLowerArm"],
	&"LeftLowerArm": [&"LeftHand"],
	&"RightShoulder": [&"RightUpperArm"],
	&"RightUpperArm": [&"RightLowerArm"],
	&"RightLowerArm": [&"RightHand"],
	&"LeftUpperLeg": [&"LeftLowerLeg"],
	&"LeftLowerLeg": [&"LeftFoot"],
	&"LeftFoot": [&"LeftToes"],
	&"RightUpperLeg": [&"RightLowerLeg"],
	&"RightLowerLeg": [&"RightFoot"],
	&"RightFoot": [&"RightToes"],
	&"LeftHand": [&"LeftMiddleIntermediate", &"LeftIndexIntermediate"],
	&"RightHand": [&"RightMiddleIntermediate", &"RightIndexIntermediate"],
	&"LeftThumbProximal": [&"LeftThumbDistal"],
	&"LeftThumbDistal": [&"DEF-thumb.03.L"],
	&"LeftIndexIntermediate": [&"LeftIndexDistal"],
	&"LeftIndexDistal": [&"DEF-f_index.03.L"],
	&"LeftMiddleIntermediate": [&"LeftMiddleDistal"],
	&"LeftMiddleDistal": [&"DEF-f_middle.03.L"],
	&"LeftRingIntermediate": [&"LeftRingDistal"],
	&"LeftRingDistal": [&"DEF-f_ring.03.L"],
	&"LeftLittleIntermediate": [&"LeftLittleDistal"],
	&"LeftLittleDistal": [&"DEF-f_pinky.03.L"],
	&"RightThumbProximal": [&"RightThumbDistal"],
	&"RightThumbDistal": [&"DEF-thumb.03.R"],
	&"RightIndexIntermediate": [&"RightIndexDistal"],
	&"RightIndexDistal": [&"DEF-f_index.03.R"],
	&"RightMiddleIntermediate": [&"RightMiddleDistal"],
	&"RightMiddleDistal": [&"DEF-f_middle.03.R"],
	&"RightRingIntermediate": [&"RightRingDistal"],
	&"RightRingDistal": [&"DEF-f_ring.03.R"],
	&"RightLittleIntermediate": [&"RightLittleDistal"],
	&"RightLittleDistal": [&"DEF-f_pinky.03.R"],
}
## Fingertip bones of the target rig and the Mixamo bones pointing the same way, to align the
## finger bones before them; the skeleton profile has no fingertips, so they are not animated.
const FINGERTIP_BONES: Dictionary[StringName, StringName] = {
	&"DEF-thumb.03.L": &"mixamorig9_LeftHandThumb3",
	&"DEF-f_index.03.L": &"mixamorig9_LeftHandIndex3",
	&"DEF-f_middle.03.L": &"mixamorig9_LeftHandMiddle3",
	&"DEF-f_ring.03.L": &"mixamorig9_LeftHandRing3",
	&"DEF-f_pinky.03.L": &"mixamorig9_LeftHandPinky3",
	&"DEF-thumb.03.R": &"mixamorig9_RightHandThumb3",
	&"DEF-f_index.03.R": &"mixamorig9_RightHandIndex3",
	&"DEF-f_middle.03.R": &"mixamorig9_RightHandMiddle3",
	&"DEF-f_ring.03.R": &"mixamorig9_RightHandRing3",
	&"DEF-f_pinky.03.R": &"mixamorig9_RightHandPinky3",
}


func _post_import(scene: Node) -> Object:
	var source: String = get_source_file().get_file()
	assert(ANIMATIONS.has(source), "No player animation configured for %s" % source)
	var player: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
	var animation: Animation = player.get_animation(SOURCE_ANIMATION).duplicate(true)

	var model: Node = (load(TARGET_MODEL) as PackedScene).instantiate()
	var target: Skeleton3D = model.find_child("GeneralSkeleton", true, false)
	_drive_target_bones(animation, target)
	var animated_bones: Array[StringName] = _rotated_bones(animation)
	_hold_missing_tracks(animation, load(HOLD_POSE_ANIMATION), target)
	_match_rest_pose(
		animation, animated_bones, scene.find_child("GeneralSkeleton", true, false), target
	)
	_carry_racket(animation, load(HOLD_POSE_ANIMATION), target)
	# Hips positions are normalized by the retarget; the target skeleton scales them back.
	var travel_speed: float = (
		_remove_root_motion(animation) * target.motion_scale / animation.length
	)

	_save(_gait_cycle(animation, target, 1.0), ANIMATIONS[source], animation.length, travel_speed)
	if REVERSED_ANIMATIONS.has(source):
		_save(
			_gait_cycle(animation, target, -1.0),
			REVERSED_ANIMATIONS[source],
			animation.length,
			travel_speed
		)
	model.free()
	return scene


func _save(cycle: Animation, cycle_name: String, cycle_time: float, travel_speed: float) -> void:
	cycle.resource_name = cycle_name
	cycle.set_meta(CYCLE_TIME_META, cycle_time)
	cycle.set_meta(TRAVEL_SPEED_META, travel_speed)
	var path: String = OUTPUT_DIR + cycle_name + ".tres"
	var error: Error = ResourceSaver.save(cycle, path)
	assert(error == OK, "Could not save %s: %s" % [path, error_string(error)])


## One looping gait cycle of the clip played in `direction` (1 forward, -1 backward), resampled to
## CYCLE_LENGTH and starting as the left foot touches down.
func _gait_cycle(clip: Animation, skeleton: Skeleton3D, direction: float) -> Animation:
	var start: float = _touchdown_time(clip, skeleton, direction)
	var cycle := Animation.new()
	cycle.length = CYCLE_LENGTH
	cycle.loop_mode = Animation.LOOP_LINEAR
	var samples: int = maxi(roundi(clip.length * RESAMPLE_RATE), 2)
	for track in clip.get_track_count():
		var type: Animation.TrackType = clip.track_get_type(track)
		var resampled: int = cycle.add_track(type)
		cycle.track_set_path(resampled, clip.track_get_path(track))
		cycle.track_set_interpolation_type(resampled, clip.track_get_interpolation_type(track))
		if clip.track_get_key_count(track) == 1:
			cycle.track_insert_key(resampled, 0.0, clip.track_get_key_value(track, 0))
			continue
		for sample in samples + 1:
			var phase: float = float(sample) / samples
			var time: float = fposmod(start + direction * phase * clip.length, clip.length)
			cycle.track_insert_key(
				resampled, phase * CYCLE_LENGTH, _sample_track(clip, track, type, time)
			)
	return cycle


func _sample_track(clip: Animation, track: int, type: Animation.TrackType, time: float) -> Variant:
	match type:
		Animation.TYPE_POSITION_3D:
			return clip.position_track_interpolate(track, time)
		Animation.TYPE_ROTATION_3D:
			return clip.rotation_track_interpolate(track, time)
		Animation.TYPE_SCALE_3D:
			return clip.scale_track_interpolate(track, time)
	assert(false, "Unexpected track type %d in a locomotion clip" % type)
	return null


## Time in the clip at which the left foot touches down when the clip plays in `direction`.
func _touchdown_time(clip: Animation, skeleton: Skeleton3D, direction: float) -> float:
	var times: Array[float] = []
	var heights: Array[float] = []
	for sample in TOUCHDOWN_SAMPLES:
		var time: float = fposmod(direction * sample * clip.length / TOUCHDOWN_SAMPLES, clip.length)
		times.append(time)
		heights.append(
			ClipPose.bone_pose(clip, skeleton, skeleton.find_bone(TOUCHDOWN_BONE), time).origin.y
		)
	var down_height: float = lerpf(heights.min(), heights.max(), TOUCHDOWN_HEIGHT)
	for sample in TOUCHDOWN_SAMPLES:
		if heights[sample] <= down_height and heights[sample - 1] > down_height:
			return times[sample]
	assert(false, "%s never touches down" % TOUCHDOWN_BONE)
	return 0.0


## Drops the tracks of the Mixamo bones the retarget left unmapped.
func _drive_target_bones(animation: Animation, target: Skeleton3D) -> void:
	for track in range(animation.get_track_count() - 1, -1, -1):
		var bone_name := StringName(animation.track_get_path(track).get_concatenated_subnames())
		if target.find_bone(bone_name) == -1:
			animation.remove_track(track)


## Rewrite the rotations of `animated_bones` so each bone points in the same world direction on
## the target skeleton as on the source. The retarget gives both skeletons the same rest
## rotations, but Mixamo rests in a T-pose and the player in an A-pose, so the rest bone
## directions differ. Target bones Mixamo does not animate (the palms, helper bones) keep their
## rotation, so the bones below them are corrected through it.
func _match_rest_pose(
	animation: Animation, animated_bones: Array[StringName], source: Skeleton3D, target: Skeleton3D
) -> void:
	# Per target bone: its global rotation relative to the global rotation of the source bone
	# it follows (its own, or for a bone Mixamo does not animate, that of its nearest animated
	# ancestor).
	var frames: Dictionary[StringName, Quaternion] = {}
	for bone in target.get_bone_count():
		var bone_name := StringName(target.get_bone_name(bone))
		var parent: int = target.get_bone_parent(bone)
		var parent_frame := Quaternion.IDENTITY
		if parent != -1:
			parent_frame = frames[StringName(target.get_bone_name(parent))]
		if not animated_bones.has(bone_name):
			frames[bone_name] = parent_frame * _kept_rotation(animation, target, bone)
		elif BONE_TAILS.has(bone_name):
			frames[bone_name] = _rest_alignment(source, target, bone_name, BONE_TAILS[bone_name])
		else:
			# Bent from its rest pose like the source bone is from its own.
			var source_rest: Basis = source.get_bone_rest(_source_bone(source, bone_name)).basis
			var target_rest: Basis = target.get_bone_rest(bone).basis
			frames[bone_name] = (
				source_rest.get_rotation_quaternion().inverse()
				* parent_frame
				* target_rest.get_rotation_quaternion()
			)

	for track in animation.get_track_count():
		var bone_name := StringName(animation.track_get_path(track).get_concatenated_subnames())
		if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		if not animated_bones.has(bone_name):
			continue
		var parent: int = target.get_bone_parent(target.find_bone(bone_name))
		var parent_frame := Quaternion.IDENTITY
		if parent != -1:
			parent_frame = frames[StringName(target.get_bone_name(parent))]
		for key in animation.track_get_key_count(track):
			var rotation: Quaternion = animation.track_get_key_value(track, key)
			animation.track_set_key_value(
				track, key, parent_frame.inverse() * rotation * frames[bone_name]
			)


## Rotation from the target bone's rest frame to the source bone's that points the bone at its
## tails the same way in both rigs: the first tail sets the direction, a second one the twist.
func _rest_alignment(
	source: Skeleton3D, target: Skeleton3D, bone_name: StringName, tails: Array
) -> Quaternion:
	var source_directions: Array[Vector3] = []
	var target_directions: Array[Vector3] = []
	for tail: StringName in tails:
		source_directions.append(
			_rest_direction(source, _source_bone(source, bone_name), _source_bone(source, tail))
		)
		target_directions.append(
			_rest_direction(target, target.find_bone(bone_name), target.find_bone(tail))
		)
	if tails.size() == 1:
		return Quaternion(target_directions[0], source_directions[0])
	var source_frame: Basis = _direction_frame(source_directions[0], source_directions[1])
	var target_frame: Basis = _direction_frame(target_directions[0], target_directions[1])
	return (source_frame * target_frame.transposed()).get_rotation_quaternion()


## Direction from `bone` to `tail` in the rest frame of `bone`.
func _rest_direction(skeleton: Skeleton3D, bone: int, tail: int) -> Vector3:
	var to_tail: Vector3 = (
		skeleton.get_bone_global_rest(bone).affine_inverse()
		* skeleton.get_bone_global_rest(tail).origin
	)
	return to_tail.normalized()


## Orthonormal basis along `direction`, twisted toward `twist`.
func _direction_frame(direction: Vector3, twist: Vector3) -> Basis:
	var x: Vector3 = direction.normalized()
	var z: Vector3 = x.cross(twist).normalized()
	return Basis(x, z.cross(x), z)


## The source bone driving the target bone `bone_name`.
func _source_bone(source: Skeleton3D, bone_name: StringName) -> int:
	var bone: int = source.find_bone(FINGERTIP_BONES.get(bone_name, bone_name))
	assert(bone != -1, "The source has no bone for %s" % bone_name)
	return bone


## Bones the clip rotates.
func _rotated_bones(animation: Animation) -> Array[StringName]:
	var bones: Array[StringName] = []
	for track in animation.get_track_count():
		if animation.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			bones.append(StringName(animation.track_get_path(track).get_concatenated_subnames()))
	return bones


## Rotation a bone Mixamo does not animate keeps: its held pose, otherwise its rest.
func _kept_rotation(animation: Animation, skeleton: Skeleton3D, bone: int) -> Quaternion:
	var path := NodePath("%GeneralSkeleton:" + skeleton.get_bone_name(bone))
	var track: int = animation.find_track(path, Animation.TYPE_ROTATION_3D)
	if track != -1:
		return animation.track_get_key_value(track, 0)
	return skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()


## Remove the horizontal travel of the hips over the clip, keeping their sway and bounce. Returns
## the distance (m) travelled.
func _remove_root_motion(animation: Animation) -> float:
	var track: int = animation.find_track(HIPS_PATH, Animation.TYPE_POSITION_3D)
	assert(track != -1, "Missing hips position track")
	var start: Vector3 = animation.position_track_interpolate(track, 0.0)
	var end: Vector3 = animation.position_track_interpolate(track, animation.length)
	var travel := Vector3(end.x - start.x, 0.0, end.z - start.z)
	for key in animation.track_get_key_count(track):
		var weight: float = animation.track_get_key_time(track, key) / animation.length
		var position: Vector3 = animation.track_get_key_value(track, key)
		animation.track_set_key_value(track, key, position - travel * weight)
	return travel.length()


## Add a constant track for every bone the pose animation drives and the clip does not, except
## the fingers.
func _hold_missing_tracks(animation: Animation, pose: Animation, skeleton: Skeleton3D) -> void:
	for pose_track in pose.get_track_count():
		var type: Animation.TrackType = pose.track_get_type(pose_track)
		var path: NodePath = pose.track_get_path(pose_track)
		if animation.find_track(path, type) != -1:
			continue
		if _is_finger(skeleton, StringName(path.get_concatenated_subnames())):
			continue
		var track: int = animation.add_track(type)
		animation.track_set_path(track, path)
		animation.track_set_interpolation_type(track, pose.track_get_interpolation_type(pose_track))
		animation.track_insert_key(track, 0.0, pose.track_get_key_value(pose_track, 0))


## Hold the racket in the racket hand: the hand keeps the pose animation's grip, and its wrist
## turns the racket as described at RACKET_HAND_BONE.
func _carry_racket(animation: Animation, pose: Animation, skeleton: Skeleton3D) -> void:
	_hold_racket_hand(animation, pose, skeleton)
	var hand: int = skeleton.find_bone(RACKET_HAND_BONE)
	var forearm: int = skeleton.get_bone_parent(hand)
	var chest: int = skeleton.find_bone(CHEST_BONE)

	# Racket rotation relative to the hand, and the direction its head points in, in the grip.
	var held_hand: Quaternion = _global_rotation(pose, skeleton, hand, 0.0)
	var held_racket: Quaternion = _global_rotation(
		pose, skeleton, skeleton.find_bone(RACKET_BONE), 0.0
	)
	var grip: Quaternion = held_hand.inverse() * held_racket
	var head_direction: Vector3 = held_racket * _racket_head_direction(skeleton)

	# At the middle of the swing, the racket turned from the pose animation's to point the way the
	# chest faces at CARRY_PITCH.
	var forearm_rotations: Array[Quaternion] = []
	var chest_rotations: Array[Quaternion] = []
	for sample in CARRY_SAMPLES:
		var time: float = animation.length * sample / CARRY_SAMPLES
		forearm_rotations.append(_global_rotation(animation, skeleton, forearm, time))
		chest_rotations.append(_global_rotation(animation, skeleton, chest, time))
	var mean_forearm: Quaternion = _mean_rotation(forearm_rotations)
	var mean_chest: Quaternion = _mean_rotation(chest_rotations)
	var chest_turn: Quaternion = (
		mean_chest * skeleton.get_bone_global_rest(chest).basis.get_rotation_quaternion().inverse()
	)
	var forward: Vector3 = chest_turn * _forward(skeleton)
	forward = Vector3(forward.x, 0.0, forward.z).normalized()
	var carried_direction: Vector3 = forward * cos(CARRY_PITCH) + Vector3.UP * sin(CARRY_PITCH)
	var carried_racket: Quaternion = Quaternion(head_direction, carried_direction) * held_racket
	# Wrist that holds the racket so with the forearm at the middle of its swing
	var carry_wrist: Quaternion = mean_forearm.inverse() * carried_racket * grip.inverse()

	var hand_track: int = animation.find_track(
		NodePath("%GeneralSkeleton:" + RACKET_HAND_BONE), Animation.TYPE_ROTATION_3D
	)
	animation.track_remove_key(hand_track, 0)
	for sample in CARRY_SAMPLES + 1:
		var time: float = animation.length * sample / CARRY_SAMPLES
		var forearm_rotation: Quaternion = _global_rotation(animation, skeleton, forearm, time)
		var swung_racket: Quaternion = forearm_rotation * carry_wrist * grip
		var steady_racket: Quaternion = (
			_global_rotation(animation, skeleton, chest, time)
			* mean_chest.inverse()
			* carried_racket
		)
		var racket: Quaternion = swung_racket.slerp(steady_racket, CARRY_STEADINESS)
		animation.rotation_track_insert_key(
			hand_track, time, forearm_rotation.inverse() * racket * grip.inverse()
		)


## Rotation of `bone` relative to the skeleton at `time` of the clip.
func _global_rotation(clip: Animation, skeleton: Skeleton3D, bone: int, time: float) -> Quaternion:
	return ClipPose.bone_pose(clip, skeleton, bone, time).basis.get_rotation_quaternion()


## Direction from the racket attachment to the middle of the racket mesh, in the attachment's
## frame: the way the racket head points.
func _racket_head_direction(skeleton: Skeleton3D) -> Vector3:
	for attachment: BoneAttachment3D in skeleton.find_children("*", "BoneAttachment3D", false):
		if attachment.bone_name != RACKET_BONE:
			continue
		var meshes: Array[Node] = attachment.find_children("*", "MeshInstance3D", false)
		assert(meshes.size() == 1, "The racket attachment must hold the racket mesh")
		var mesh: MeshInstance3D = meshes[0]
		return (mesh.transform * mesh.get_aabb().get_center()).normalized()
	assert(false, "The skeleton has no racket attachment")
	return Vector3.ZERO


## Horizontal direction the skeleton faces in its rest pose: from the ankle to the toes.
func _forward(skeleton: Skeleton3D) -> Vector3:
	var foot: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone(TOUCHDOWN_BONE)).origin
	var toes: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone(&"LeftToes")).origin
	return Vector3(toes.x - foot.x, 0.0, toes.z - foot.z).normalized()


## Average of `rotations`.
func _mean_rotation(rotations: Array[Quaternion]) -> Quaternion:
	var sum := Vector4.ZERO
	for rotation in rotations:
		if rotation.dot(rotations[0]) < 0.0:
			rotation = -rotation
		sum += Vector4(rotation.x, rotation.y, rotation.z, rotation.w)
	sum = sum.normalized()
	return Quaternion(sum.x, sum.y, sum.z, sum.w)


## Replace the tracks of the racket hand and every bone below it with the pose animation's.
func _hold_racket_hand(animation: Animation, pose: Animation, skeleton: Skeleton3D) -> void:
	var hand: int = skeleton.find_bone(RACKET_HAND_BONE)
	for pose_track in pose.get_track_count():
		var type: Animation.TrackType = pose.track_get_type(pose_track)
		var path: NodePath = pose.track_get_path(pose_track)
		if not _is_in_branch(skeleton, skeleton.find_bone(path.get_concatenated_subnames()), hand):
			continue
		var held: int = animation.find_track(path, type)
		if held != -1:
			animation.remove_track(held)
		var track: int = animation.add_track(type)
		animation.track_set_path(track, path)
		animation.track_set_interpolation_type(track, pose.track_get_interpolation_type(pose_track))
		animation.track_insert_key(track, 0.0, pose.track_get_key_value(pose_track, 0))


## Whether `bone` is `branch` or below it.
func _is_in_branch(skeleton: Skeleton3D, bone: int, branch: int) -> bool:
	while bone != -1:
		if bone == branch:
			return true
		bone = skeleton.get_bone_parent(bone)
	return false


## Whether the bone belongs to a hand (below the hand bone).
func _is_finger(skeleton: Skeleton3D, bone_name: StringName) -> bool:
	var bone: int = skeleton.get_bone_parent(skeleton.find_bone(bone_name))
	while bone != -1:
		if HAND_BONES.has(StringName(skeleton.get_bone_name(bone))):
			return true
		bone = skeleton.get_bone_parent(bone)
	return false
