extends Node3D


var active_cam_index := 0
var cams: Array

func _ready() -> void:
	cams = get_children() 


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			active_cam_index = (active_cam_index + 1) % cams.size()
			cams[active_cam_index].current = true
