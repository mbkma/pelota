class_name BallFactory
extends RefCounted

var _ball_scene: PackedScene


func _init(ball_scene: PackedScene = null) -> void:
	_ball_scene = ball_scene if ball_scene else GlobalScenes.BALL_SCENE


func create_ball(initial_position: Vector3, initial_velocity: Vector3) -> Ball:
	if not _ball_scene:
		push_error("BallFactory.create_ball: ball scene is not configured")
		return null

	var ball: Ball = _ball_scene.instantiate()
	ball.initial_position = initial_position
	ball.initial_velocity = initial_velocity
	return ball
