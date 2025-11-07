extends Node3D

@export var cams: Array[Camera3D]
var active_cam_index := 0


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			active_cam_index = (active_cam_index + 1) % cams.size()
			cams[active_cam_index].current = true
