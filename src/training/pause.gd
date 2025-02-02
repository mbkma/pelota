extends Node


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("pause"):
		print("pause pressed ", get_tree().paused)
		get_tree().paused = not get_tree().paused
		print("Game Paused ", get_tree().paused)
