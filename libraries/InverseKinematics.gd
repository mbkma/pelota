extends Node3D

@export var skeleton_path: NodePath : set = _set_skeleton_path
@export var bone_name: String = ""
@export var look_at_axis = 1 # (int, "X-up", "Y-up", "Z-up")
@export var interpolation = 1.0 # (float, 0.0, 1.0, 0.001)
@export var use_our_rotation_x: bool = false
@export var use_our_rotation_y: bool = false
@export var use_our_rotation_z: bool = false
@export var use_negative_our_rot: bool = false
@export var additional_rotation: Vector3 = Vector3()
@export var debug_messages: bool = false

var skeleton_to_use: Skeleton3D = null
var first_call: bool = true


func _physics_process(_delta):
	update_skeleton()


func update_skeleton():
	# NOTE: Because get_node doesn't work in _ready, we need to skip
	# a call before doing anything.
	if first_call:
		first_call = false
		if skeleton_to_use == null:
			_set_skeleton_path(skeleton_path)

	# If we do not have a skeleton and/or we're not supposed to update, then return.
	if skeleton_to_use == null:
		return

	# Get the bone index.
	var bone: int = skeleton_to_use.find_bone(bone_name)

	# If no bone is found (-1), then return and optionally print an error.
	if bone == -1:
		if debug_messages:
			print(name, " - IK_LookAt: No bone in skeleton found with name [", bone_name, "]!")
		return

	# get the bone's global transform pose.
	var rest = skeleton_to_use.get_bone_global_pose(bone)

	# Convert our position relative to the skeleton's transform.
	var target_pos = global_transform.origin * skeleton_to_use.global_transform

	# Call helper's look_at function with the chosen up axis.
	if look_at_axis == 0:
		rest = rest.looking_at(target_pos, Vector3.RIGHT)
	elif look_at_axis == 1:
		rest = rest.looking_at(target_pos, Vector3.UP)
	elif look_at_axis == 2:
		rest = rest.looking_at(target_pos, Vector3.FORWARD)
	else:
		rest = rest.looking_at(target_pos, Vector3.UP)
		if debug_messages:
			print(name, " - IK_LookAt: Unknown look_at_axis value!")

	# Get the rotation euler of the bone and of this node.
	var rest_euler = rest.basis.get_euler()
	var self_euler = global_transform.basis.orthonormalized().get_euler()

	# Flip the rotation euler if using negative rotation.
	if use_negative_our_rot:
		self_euler = -self_euler

	# Apply this node's rotation euler checked each axis, if wanted/required.
	if use_our_rotation_x:
		rest_euler.x = self_euler.x
	if use_our_rotation_y:
		rest_euler.y = self_euler.y
	if use_our_rotation_z:
		rest_euler.z = self_euler.z

	# Make a new basis with the, potentially, changed euler angles.
	rest.basis = Basis(rest_euler)

	# Apply additional rotation stored in additional_rotation to the bone.
	if additional_rotation != Vector3.ZERO:
		rest.basis = rest.basis.rotated(rest.basis.x, deg_to_rad(additional_rotation.x))
		rest.basis = rest.basis.rotated(rest.basis.y, deg_to_rad(additional_rotation.y))
		rest.basis = rest.basis.rotated(rest.basis.z, deg_to_rad(additional_rotation.z))

	skeleton_to_use.set_bone_global_pose_override(bone, rest, interpolation, true)


func _set_skeleton_path(new_value):
	# Because get_node doesn't work in the first call, we just want to assign instead.
	# This is to get around a issue with NodePaths exposed to the editor.
	if first_call:
		skeleton_path = new_value
		return

	# Assign skeleton_path to whatever value is passed.
	skeleton_path = new_value

	if skeleton_path == null:
		if debug_messages:
			print(name, " - IK_LookAt: No Nodepath selected for skeleton_path!")
		return

	# Get the node at that location, if there is one.
	var temp = get_node(skeleton_path)
	if temp != null:
		if temp is Skeleton3D:
			skeleton_to_use = temp
			if debug_messages:
				print(name, " - IK_LookAt: attached to (new) skeleton")
		else:
			skeleton_to_use = null
			if debug_messages:
				print(name, " - IK_LookAt: skeleton_path does not point to a skeleton!")
	else:
		if debug_messages:
			print(name, " - IK_LookAt: No Nodepath selected for skeleton_path!")
