class_name SceneSwitcher
extends Node

@onready var current_scene = $MainMenu

func change_level(next_packed_scene: PackedScene, init_data = null) -> void:
	var next_scene := next_packed_scene.instantiate()
	current_scene.queue_free()
	call_deferred("add_child", next_scene)
	if next_scene.has_method("init_scene") and init_data:
		next_scene.init_scene(init_data)
	set_deferred("current_scene", next_scene)
	Loggie.msg("current_scene: ", current_scene).info()
