class_name Television
extends Node

signal active_camera_changed(camera)

@onready var player_cameras := [$StaticSouthCam, $StaticNorthCam, $StaticEastCam]
@onready var mobile_camera1 = $FlyingCam
@onready var director = $Director
@onready var television_hud: Control = $TelevisionHUD

var active_camera: Camera3D: set = set_active_camera
var active_player_camera_index := 0
var active_follow_target = null


func _unhandled_input(event):
	if event.is_action_pressed("ui_select"):
		if director.is_playing():
			stop_broadcast()
			set_active_camera(player_cameras[active_player_camera_index])


func _ready():
	director.animation_finished.connect(on_Director_animation_finished)


func setup_singles_match(singles_match):
	$TelevisionHUD.setup_singles_match(singles_match)
	singles_match.match_data.match_score.games_changed.connect(on_MatchScore_games_changed)
	active_follow_target = singles_match.players[0]


func _physics_process(delta: float) -> void:
	if !active_follow_target or !active_camera:
		return
#	active_camera.rotation.y = deg_to_rad(active_follow_target.position.x)


func on_MatchScore_games_changed(score):
	if ((score.games[0] + score.games[1]) % 2) == 1:
		director.play("games_changed_broadcast")
		active_player_camera_index = 1 - active_player_camera_index
		active_camera = player_cameras[active_player_camera_index]


func stop_broadcast():
	director.stop()


func start_broadcast():
	director.play("start_broadcast")


func set_active_camera(camera):
	active_camera = camera
	camera.current = true
	emit_signal("active_camera_changed", camera)


func on_Director_animation_finished(animation_name):
	match animation_name:
		"start_broadcast":
			director.play("start_match")
		"start_match":
			set_active_camera(player_cameras[0])
		"games_changed_broadcast":
			set_active_camera(player_cameras[active_player_camera_index])
