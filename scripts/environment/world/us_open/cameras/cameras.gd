class_name Cameras
extends Node3D

@onready var flying_cam: Camera3D = $FlyingCam
@onready var top_front: Camera3D = $TopFront
@onready var top_back: Camera3D = $TopBack
@onready var middle_front: Camera3D = $MiddleFront
@onready var middle_back: Camera3D = $MiddleBack
@onready var court_side_front: Camera3D = $CourtSideFront
@onready var court_side_back: Camera3D = $CourtSideBack
@onready var camera_top: Camera3D = $CameraTop

var active_cam_index := 0
var cams: Array

func _ready() -> void:
	cams = get_children() 


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			active_cam_index = (active_cam_index + 1) % cams.size()
			cams[active_cam_index].current = true

# call this after the players have been placed
func set_camera_for_player(player: Player) -> void:
	if sign(player.position.z) < 0:
		player.camera = middle_back
	else:
		player.camera = middle_front
		player.camera.make_current()

func disable_all() -> void:
	for c in cams:
		c.current = false
