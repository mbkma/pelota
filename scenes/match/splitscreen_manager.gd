## Split screen for two human players: X cycles between the normal view, side by side and
## top/bottom views, each half following one player from behind.
class_name SplitscreenManager
extends Control

enum SplitscreenMode { NORMAL, VERTICAL_SPLIT, HORIZONTAL_SPLIT }

## Follow camera placement relative to its player: distance behind, height, and how far
## ahead of the player (toward the net) it looks.
const FOLLOW_DISTANCE: float = 7.0
const FOLLOW_HEIGHT: float = 4.5
const FOLLOW_LOOK_AHEAD: float = 9.0
const FOLLOW_FOV: float = 60.0

@export var cameras: MatchCameras
@export var player0: Player
@export var player1: Player

var _mode: SplitscreenMode = SplitscreenMode.NORMAL
## Follow cameras [player0, player1] per split mode
var _split_cameras: Dictionary[SplitscreenMode, Array] = {}

@onready var _split_containers: Dictionary[SplitscreenMode, Control] = {
	SplitscreenMode.VERTICAL_SPLIT: $HBoxContainer,
	SplitscreenMode.HORIZONTAL_SPLIT: $VBoxContainer,
}


func _ready() -> void:
	_split_cameras = {
		SplitscreenMode.VERTICAL_SPLIT:
		[
			_create_camera($HBoxContainer/LeftView/LeftViewport),
			_create_camera($HBoxContainer/RightView/RightViewport),
		],
		SplitscreenMode.HORIZONTAL_SPLIT:
		[
			_create_camera($VBoxContainer/TopView/TopViewport),
			_create_camera($VBoxContainer/BottomView/BottomViewport),
		],
	}
	_set_mode(SplitscreenMode.NORMAL)
	# A player taken over by a human (from the pause menu) steers with its split view too.
	player0.controller_changed.connect(_set_view_cameras)
	player1.controller_changed.connect(_set_view_cameras)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and event.keycode == KEY_X:
		_set_mode(((_mode + 1) % SplitscreenMode.size()) as SplitscreenMode)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var split_cameras: Array = _split_cameras[_mode]
	_follow(split_cameras[0], player0)
	_follow(split_cameras[1], player1)


func _create_camera(viewport: SubViewport) -> Camera3D:
	var camera := Camera3D.new()
	camera.fov = FOLLOW_FOV
	viewport.add_child(camera)
	return camera


func _set_mode(mode: SplitscreenMode) -> void:
	_mode = mode
	for container_mode in _split_containers:
		_split_containers[container_mode].visible = container_mode == mode
	var split: bool = mode != SplitscreenMode.NORMAL
	set_process(split)
	# The split views cover the whole screen, so the main view would render its 3D unseen.
	get_viewport().disable_3d = split
	if split:
		for camera: Camera3D in _split_cameras[mode]:
			camera.make_current()
	else:
		cameras.active_cam.make_current()
	_set_view_cameras()


## Human players steer relative to the camera of their split view (null: the main camera).
func _set_view_cameras() -> void:
	var split: bool = _mode != SplitscreenMode.NORMAL
	_set_view_camera(player0, _split_cameras[_mode][0] if split else null)
	_set_view_camera(player1, _split_cameras[_mode][1] if split else null)


func _set_view_camera(player: Player, camera: Camera3D) -> void:
	if player.controller is HumanController:
		(player.controller as HumanController).view_camera = camera


## Places a camera behind and above its player, looking toward the net.
func _follow(camera: Camera3D, player: Player) -> void:
	var backward: Vector3 = player.global_basis.z
	camera.global_position = (
		player.global_position + backward * FOLLOW_DISTANCE + Vector3.UP * FOLLOW_HEIGHT
	)
	camera.look_at(player.global_position - backward * FOLLOW_LOOK_AHEAD, Vector3.UP)
