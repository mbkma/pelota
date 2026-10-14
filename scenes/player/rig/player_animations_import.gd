## Post-import script of the player animation sets (see tools/blender/export_player_assets.py): a
## rig retargeted to the Pelota skeleton profile (see game_rig_bone_map.tres) with its animations.
## Saves the animations listed in the set's AnimationSetImport (SPECS_DIR/<file name>_import.tres)
## with their names, loop modes and markers. The import keeps only the tracks of the profile's
## bones, so the saved animations play on every body.
@tool
extends EditorScenePostImport

const SPECS_DIR: String = "res://scenes/player/animations/"
## Mesh the exporter adds so the rig imports as a skeleton
const SKIN_PROXY: StringName = &"SkinProxy"


func _post_import(scene: Node) -> Object:
	var source: String = get_source_file()
	var spec_path: String = SPECS_DIR.path_join(source.get_file().get_basename() + "_import.tres")
	assert(ResourceLoader.exists(spec_path), "%s has no import spec %s" % [source, spec_path])
	var spec: AnimationSetImport = load(spec_path)
	var player: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
	var skeleton: Skeleton3D = scene.get_node("%GeneralSkeleton")
	for clip in spec.clips:
		assert(player.has_animation(clip.source), "%s has no animation %s" % [source, clip.source])
		var animation: Animation = player.get_animation(clip.source).duplicate(true)
		animation.resource_name = clip.name
		animation.loop_mode = Animation.LOOP_LINEAR if clip.loop else Animation.LOOP_NONE
		for marker in animation.get_marker_names():
			animation.remove_marker(marker)
		for marker in clip.markers:
			var time: float = clip.markers[marker]
			assert(time <= animation.length, "%s: %s after the end" % [clip.name, marker])
			animation.add_marker(marker, time)
		_check_tracks(animation, skeleton)
		var path: String = spec.output_dir.path_join(String(clip.name) + ".tres")
		var error: Error = ResourceSaver.save(animation, path)
		assert(error == OK, "Could not save %s: %s" % [path, error_string(error)])
	scene.find_child(SKIN_PROXY, true, false).free()
	return scene


## Every track has to drive a bone of the skeleton.
func _check_tracks(animation: Animation, skeleton: Skeleton3D) -> void:
	for track in animation.get_track_count():
		var bone: String = animation.track_get_path(track).get_concatenated_subnames()
		assert(skeleton.find_bone(bone) != -1, "%s animates %s" % [animation.resource_name, bone])
