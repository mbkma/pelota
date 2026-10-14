## Moves the racket's sweet spot by `reach` with the racket arm: bends it at the elbow to the
## distance from the shoulder, then turns it at the shoulder toward the reached point. Forearm,
## hand and racket move as one, so the racket keeps its angle to the forearm. The modifier's
## influence fades the reach in and out (see Model.reach_toward).
class_name RacketReachModifier
extends SkeletonModifier3D

## Least angle (rad) the elbow stays away from fully stretched or folded
const ELBOW_MARGIN: float = 0.05

@export var shoulder_bone: StringName = &"RightUpperArm"
@export var elbow_bone: StringName = &"RightLowerArm"
## Bone holding the racket (see the body's RacketAttachment)
@export var grip_bone: StringName = &"RacketGrip"

## Sweet spot of the racket relative to the grip bone
var sweet_spot: Vector3 = Vector3.ZERO
## World offset (m) the sweet spot moves by at full influence
var reach: Vector3 = Vector3.ZERO


func _process_modification() -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if reach == Vector3.ZERO:
		return
	var shoulder: int = skeleton.find_bone(shoulder_bone)
	var elbow: int = skeleton.find_bone(elbow_bone)
	var shoulder_pose: Transform3D = skeleton.get_bone_global_pose(shoulder)
	var elbow_pose: Transform3D = skeleton.get_bone_global_pose(elbow)
	var spot: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone(grip_bone)) * sweet_spot
	var target: Vector3 = spot + skeleton.global_basis.inverse() * reach

	# Bend the elbow so the sweet spot gets as far from the shoulder as the target.
	var to_shoulder: Vector3 = shoulder_pose.origin - elbow_pose.origin
	var to_spot: Vector3 = spot - elbow_pose.origin
	var bend_axis: Vector3 = to_shoulder.cross(to_spot).normalized()
	if bend_axis != Vector3.ZERO:
		var upper: float = to_shoulder.length()
		var lower: float = to_spot.length()
		var distance: float = shoulder_pose.origin.distance_to(target)
		var cosine: float = (
			(upper * upper + lower * lower - distance * distance) / (2.0 * upper * lower)
		)
		var angle: float = clampf(acos(clampf(cosine, -1.0, 1.0)), ELBOW_MARGIN, PI - ELBOW_MARGIN)
		var bend := Quaternion(bend_axis, angle - to_shoulder.angle_to(to_spot))
		skeleton.set_bone_global_pose(
			elbow, Transform3D(Basis(bend) * elbow_pose.basis, elbow_pose.origin)
		)
		spot = elbow_pose.origin + bend * to_spot

	# Turn the arm at the shoulder toward the target.
	var aim := Quaternion(
		(spot - shoulder_pose.origin).normalized(), (target - shoulder_pose.origin).normalized()
	)
	skeleton.set_bone_global_pose(
		shoulder, Transform3D(Basis(aim) * shoulder_pose.basis, shoulder_pose.origin)
	)
