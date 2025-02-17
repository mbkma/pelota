extends Control

@export var root: Node

func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"pause"):
		if get_tree().paused:
			hide()
			get_tree().paused = false
		else:
			show()
			get_tree().paused = true


func _on_resume_pressed() -> void:
	hide()
	get_tree().paused = false


func _on_back_pressed() -> void:
	root.to_main_menu()
