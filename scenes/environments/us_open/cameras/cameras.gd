## Broadcast and debug cameras of the match; 1 cycles through them.
class_name MatchCameras
extends Node3D

@export var cams: Array[Camera3D]
## Camera active at the start
@export var active_cam: Camera3D

@onready var _top_front: Camera3D = $TopFront
@onready var _top_back: Camera3D = $TopBack


func _ready() -> void:
	activate(active_cam)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and event.keycode == KEY_1:
		activate(cams[(cams.find(active_cam) + 1) % cams.size()])


func register_camera(camera: Camera3D) -> void:
	cams.append(camera)


func activate(camera: Camera3D) -> void:
	active_cam = camera
	camera.make_current()


## Makes the broadcast camera behind the given player's baseline the active camera.
func show_from_behind(player: Player) -> void:
	activate(_top_front if player.global_position.z > 0.0 else _top_back)
