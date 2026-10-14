## Post-import script of the player bodies (see tools/blender/export_player_assets.py): a rig
## retargeted to the Pelota skeleton profile (see game_rig_bone_map.tres) with its meshes named by
## slot. Adds the attachments the player model hangs the racket, the sweat drops and the ball held
## for the serve on, and gives the shirt its rest positions for the sweat patches.
@tool
extends EditorScenePostImport

## Mesh slots every body has (see Model)
const SLOTS: Array[StringName] = [&"Body", &"Shirt", &"Shorts", &"Shoes", &"Hair"]
## Attachments added to the skeleton, by the bone they follow
const ATTACHMENTS: Dictionary[StringName, StringName] = {
	&"RacketAttachment": &"RacketGrip",
	&"HeadAttachment": &"Head",
	&"TossAttachment": &"LeftHand",
}


func _post_import(scene: Node) -> Object:
	var skeleton: Skeleton3D = scene.get_node("%GeneralSkeleton")
	for slot in SLOTS:
		assert(_find_mesh(scene, slot) != null, "The body has no %s mesh" % slot)
	for attachment_name in ATTACHMENTS:
		var bone: StringName = ATTACHMENTS[attachment_name]
		assert(skeleton.find_bone(bone) != -1, "The skeleton has no %s bone" % bone)
		var attachment := BoneAttachment3D.new()
		attachment.name = attachment_name
		attachment.bone_name = bone
		skeleton.add_child(attachment)
		attachment.owner = scene
		attachment.unique_name_in_owner = true
	var shirt: MeshInstance3D = _find_mesh(scene, &"Shirt")
	shirt.mesh = _with_rest_positions(shirt.mesh)
	return scene


func _find_mesh(scene: Node, slot: StringName) -> MeshInstance3D:
	return scene.find_child(slot, true, false) as MeshInstance3D


## `mesh` with each vertex's rest position also in CUSTOM0, for the sweat patches (see
## sweat_patches.gdshader), which have to follow the cloth when the player moves.
func _with_rest_positions(mesh: ArrayMesh) -> ArrayMesh:
	var result := ArrayMesh.new()
	result.resource_name = mesh.resource_name
	for surface in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var rest := PackedFloat32Array()
		rest.resize(positions.size() * 4)
		for i in positions.size():
			rest[i * 4] = positions[i].x
			rest[i * 4 + 1] = positions[i].y
			rest[i * 4 + 2] = positions[i].z
		arrays[Mesh.ARRAY_CUSTOM0] = rest
		var flags: int = (
			(mesh.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
			| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		)
		result.add_surface_from_arrays(
			mesh.surface_get_primitive_type(surface), arrays, [], {}, flags
		)
		result.surface_set_material(surface, mesh.surface_get_material(surface))
	return result
