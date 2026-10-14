## Poses of a skeleton's bones in an animation, worked out from its tracks without playing it.
## Bones without a track keep their rest; positions are only animated where the clip has a
## position track (the hips), scaled by the skeleton's motion scale like the AnimationMixer does.
class_name ClipPose
extends RefCounted


## Pose of `bone` relative to the skeleton at `time` (s) of `animation`.
static func bone_pose(
	animation: Animation, skeleton: Skeleton3D, bone: int, time: float
) -> Transform3D:
	var local: Transform3D = _local_pose(animation, skeleton, bone, time)
	var parent: int = skeleton.get_bone_parent(bone)
	if parent == -1:
		return local
	return bone_pose(animation, skeleton, parent, time) * local


## Pose of `bone` relative to the skeleton with `low` at `low_time` and `high` at `high_time`
## blended by `weight` (0: `low`), as the AnimationTree blends them: rotations slerped, positions
## lerped.
static func blended_bone_pose(
	low: Animation,
	low_time: float,
	high: Animation,
	high_time: float,
	weight: float,
	skeleton: Skeleton3D,
	bone: int
) -> Transform3D:
	var low_local: Transform3D = _local_pose(low, skeleton, bone, low_time)
	var high_local: Transform3D = _local_pose(high, skeleton, bone, high_time)
	var local := Transform3D(
		Basis(
			low_local.basis.get_rotation_quaternion().slerp(
				high_local.basis.get_rotation_quaternion(), weight
			)
		),
		low_local.origin.lerp(high_local.origin, weight)
	)
	var parent: int = skeleton.get_bone_parent(bone)
	if parent == -1:
		return local
	return blended_bone_pose(low, low_time, high, high_time, weight, skeleton, parent) * local


## Pose of `bone` relative to its parent at `time` (s) of `animation`.
static func _local_pose(
	animation: Animation, skeleton: Skeleton3D, bone: int, time: float
) -> Transform3D:
	var path := NodePath("%GeneralSkeleton:" + skeleton.get_bone_name(bone))
	var rest: Transform3D = skeleton.get_bone_rest(bone)
	var rotation: Quaternion = rest.basis.get_rotation_quaternion()
	var position: Vector3 = rest.origin
	var rotation_track: int = animation.find_track(path, Animation.TYPE_ROTATION_3D)
	if rotation_track != -1:
		rotation = animation.rotation_track_interpolate(rotation_track, time)
	var position_track: int = animation.find_track(path, Animation.TYPE_POSITION_3D)
	if position_track != -1:
		position = (
			animation.position_track_interpolate(position_track, time) * skeleton.motion_scale
		)
	return Transform3D(Basis(rotation), position)
