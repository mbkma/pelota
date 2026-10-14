## Keeps the upper body of a stroke turned as in the stroke while the hips run with the legs: turns
## the spine by the rotation from the hips as they are to the stroke's hips (`stroke_hips`),
## spread evenly over the TORSO_BONES, so the chest ends up as in the stroke. The modifier's
## influence follows how much the legs run under the stroke (see Model).
class_name TorsoTwistModifier
extends SkeletonModifier3D

## Bones from the hips up that share the twist
const TORSO_BONES: Array[StringName] = [&"Spine", &"LowerChest", &"Chest"]
const HIPS_BONE: StringName = &"Hips"

## Rotation of the hips in the stroke, relative to the skeleton
var stroke_hips: Quaternion = Quaternion.IDENTITY


func _process_modification() -> void:
	var skeleton: Skeleton3D = get_skeleton()
	var hips: Quaternion = (
		skeleton.get_bone_global_pose(skeleton.find_bone(HIPS_BONE)).basis.get_rotation_quaternion()
	)
	var share: Quaternion = Quaternion.IDENTITY.slerp(
		stroke_hips * hips.inverse(), 1.0 / TORSO_BONES.size()
	)
	for bone_name in TORSO_BONES:
		var bone: int = skeleton.find_bone(bone_name)
		var pose: Transform3D = skeleton.get_bone_global_pose(bone)
		skeleton.set_bone_global_pose(bone, Transform3D(Basis(share) * pose.basis, pose.origin))
