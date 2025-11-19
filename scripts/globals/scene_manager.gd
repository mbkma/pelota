## Global scene manager for easy scene switching from anywhere with state passing
extends Node

# Store data to pass to next scene
var _scene_data: Dictionary = {}

## Get the SceneSwitcher instance (the root scene)
func _get_scene_switcher() -> SceneSwitcher:
	# Find the SceneSwitcher by checking for the change_level method
	var root = get_tree().root
	for child in root.get_children():
		if child.has_method("change_level"):
			return child

	push_error("SceneSwitcher not found in scene tree!")
	return null


## Switch to a packed scene with optional state data
func goto(packed_scene: PackedScene, data: Dictionary = {}) -> void:
	print("goto", packed_scene)
	_scene_data = data
	var switcher := _get_scene_switcher()
	switcher.change_level(packed_scene, data)


## Get the data that was passed from the previous scene
func get_scene_data() -> Dictionary:
	return _scene_data


## Get a specific data value from the previous scene
func get_scene_data_value(key: String, default = null):
	return _scene_data.get(key, default)


## Set data to pass to next scene (for chaining)
func set_scene_data(data: Dictionary) -> SceneManager:
	_scene_data = data
	return self


## Clear scene data
func clear_scene_data() -> void:
	_scene_data = {}
