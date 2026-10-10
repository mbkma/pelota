## Broadcast and debug cameras of the match; 1 cycles through them. The TV cameras among them
## move like real broadcast cameras (see TvCamera).
class_name MatchCameras
extends Node3D

@export var cams: Array[Camera3D]
## Camera active at the start
@export var active_cam: Camera3D
## Camera showing the player on the front half (z > 0) from behind
@export var front_player_cam: Camera3D
## Camera showing the player on the back half (z < 0) from behind
@export var back_player_cam: Camera3D


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
	activate(front_player_cam if player.global_position.z > 0.0 else back_player_cam)


## Starts the match broadcast: the active TV camera slowly zooms in.
func open_match() -> void:
	if active_cam is TvCamera:
		(active_cam as TvCamera).open_shot()


## Between points the TV cameras now and then reframe slightly.
func reframe_tv_cameras() -> void:
	for camera in cams:
		if camera is TvCamera:
			(camera as TvCamera).reframe()


## Before a serve the TV cameras on the returner's end widen to keep the returner in the picture.
func frame_return(receiver: Player) -> void:
	for camera in cams:
		if camera is TvCamera:
			(camera as TvCamera).frame_return(receiver)


## After the serve the TV cameras settle back to their standard shot.
func settle_after_serve() -> void:
	for camera in cams:
		if camera is TvCamera:
			(camera as TvCamera).settle_after_serve()
