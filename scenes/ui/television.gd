## Broadcast camera and director system for match coverage
class_name Television
extends Node

## Emitted when the active camera changes
signal active_camera_changed(camera: Camera3D)

@onready var _player_cameras: Array[Camera3D] = [$StaticSouthCam, $StaticNorthCam, $StaticEastCam]
@onready var _mobile_camera: Camera3D = $FlyingCam
@onready var _director: AnimationPlayer = $Director
@onready var _television_hud: Control = $TelevisionHUD

## Currently active broadcast camera
var active_camera: Camera3D:
	set = set_active_camera

## Index of currently active player/static camera (0-2)
var _active_player_camera_index: int = 0

## Target player node for camera to follow
var _active_follow_target: Node3D = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_select"):
		if _director.is_playing():
			stop_broadcast()
			set_active_camera(_player_cameras[_active_player_camera_index])


func _ready() -> void:
	_director.animation_finished.connect(_on_director_animation_finished)


## Setup broadcast for a singles match, connecting to score updates
func setup_singles_match(singles_match: Object) -> void:
	_television_hud.setup_singles_match(singles_match)
	singles_match.match_data.match_score.game_changed.connect(_on_match_score_game_changed)
	_active_follow_target = singles_match.players[0]


func _physics_process(_delta: float) -> void:
	if not _active_follow_target or not active_camera:
		return


## Handle game score change, triggering broadcast camera transition
func _on_match_score_game_changed(score: Score) -> void:
	if ((score.games[0] + score.games[1]) % 2) == 1:
		_director.play("games_changed_broadcast")
		_active_player_camera_index = 1 - _active_player_camera_index
		active_camera = _player_cameras[_active_player_camera_index]


## Stop the broadcast director animation
func stop_broadcast() -> void:
	_director.stop()


## Start the broadcast with opening animation sequence
func start_broadcast() -> void:
	_director.play("start_broadcast")


## Set the active broadcast camera and emit change signal
func set_active_camera(camera: Camera3D) -> void:
	active_camera = camera
	camera.current = true
	active_camera_changed.emit(camera)


## Handle director animation completion, transitioning to next camera shot
func _on_director_animation_finished(animation_name: StringName) -> void:
	match animation_name:
		"start_broadcast":
			_director.play("start_match")
		"start_match":
			set_active_camera(_player_cameras[0])
		"games_changed_broadcast":
			set_active_camera(_player_cameras[_active_player_camera_index])
