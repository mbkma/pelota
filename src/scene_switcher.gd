extends Node

@onready var current_level = $MainMenu


func _ready() -> void:
	current_level.connect("level_changed",Callable(self,"on_level_changed"))



func replace_main_scene(resource, init_data):
	call_deferred("on_level_changed", resource, init_data)


func on_level_changed(next_level_resource: Resource, init_data = null) -> void:
	var next_level = next_level_resource.instantiate()
	add_child(next_level)
	next_level.connect("level_changed",Callable(self,"on_level_changed"))
	if next_level.has_method("init_scene") and init_data:
		next_level.init_scene(init_data)
	current_level.queue_free()
	current_level = next_level
