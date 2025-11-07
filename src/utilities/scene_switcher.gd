extends Node

@onready var current_scene = $MainMenu


func _ready() -> void:
	current_scene.level_changed.connect(on_level_changed)


func on_level_changed(next_packed_scene: PackedScene, init_data = null) -> void:
	var next_scene := next_packed_scene.instantiate()
	current_scene.queue_free()
	call_deferred("add_child", next_scene)
	next_scene.level_changed.connect(on_level_changed)
	if next_scene.has_method("init_scene") and init_data:
		next_scene.init_scene(init_data)
	set_deferred("current_scene", next_scene)
