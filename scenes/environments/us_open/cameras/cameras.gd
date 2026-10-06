class_name MatchCameras
extends Node3D

@export var cams: Array[Camera3D]

@export var active_cam: Camera3D

var active_cam_index := 0
var player0: Player
var player1: Player

@onready var flying_cam: Camera3D = $FlyingCam
@onready var top_front: Camera3D = $TopFront
@onready var top_back: Camera3D = $TopBack
@onready var middle_front: Camera3D = $MiddleFront
@onready var middle_back: Camera3D = $MiddleBack
@onready var court_side_front: Camera3D = $CourtSideFront
@onready var court_side_back: Camera3D = $CourtSideBack
@onready var camera_top: Camera3D = $CameraTop

func _ready() -> void:
	if cams.is_empty():
		return

	if not active_cam:
		active_cam = court_side_back if court_side_back else cams[0]

	active_cam_index = max(0, cams.find(active_cam))
	active_cam.make_current()

func register_camera(camera: Camera3D):
	cams.append(camera)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			active_cam_index = (active_cam_index + 1) % cams.size()
			var next_cam: Camera3D = cams[active_cam_index]
			if next_cam:
				active_cam = next_cam
				next_cam.make_current()


## Makes the broadcast camera behind the given player's baseline the active camera.
func show_from_behind(player: Player) -> void:
	var camera: Camera3D = top_front if player.global_position.z > 0.0 else top_back
	active_cam = camera
	active_cam_index = max(0, cams.find(camera))
	camera.make_current()

func disable_all() -> void:
	for c in cams:
		c.current = false
