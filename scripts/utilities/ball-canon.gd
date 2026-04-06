extends Node3D

const BALL_FACTORY_SCRIPT: Script = preload("res://scripts/core/ball_factory.gd")

@onready var ball_spawn_marker_3d: Marker3D = $Marker3D
# Given parameters
@export var velocity_length: float = 10.0  # Example speed of the ball
@export var shoot_off_angle: float = 45.0  # Angle from the horizontal plane in degrees
@export var horizontal_angle: float = 0.0  # Angle in the horizontal plane in degrees
@export var ball_scene: PackedScene
@export var players: Array[Player] = []

var _ball_factory: BallFactory


func _ready() -> void:
	Loggie.msg("global basis: ", global_basis).info()
	Loggie.msg("local basis: ", basis).info()
	_ball_factory = BALL_FACTORY_SCRIPT.new(ball_scene)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("request_ball"):
		# Calculate the initial velocity from canon orientation and tuning values.
		var initial_velocity = (
			-global_basis.z.normalized() * velocity_length
			+ global_basis.y.normalized() * shoot_off_angle
		)

		var ball: Ball = _ball_factory.create_ball(ball_spawn_marker_3d.global_position, initial_velocity)
		if not ball:
			return
		get_parent().add_child(ball)
		_assign_ball_to_players(ball)
		ball.predict_trajectory()


func _assign_ball_to_players(ball: Ball) -> void:
	var assigned: bool = false

	for target_player in _resolve_target_players():
		target_player.set_active_ball(ball)
		assigned = true

	if not assigned:
		push_warning("ball-canon: no target players configured for ball assignment")


func _resolve_target_players() -> Array[Player]:
	var targets: Array[Player] = []

	for target_player in players:
		if target_player and not targets.has(target_player):
			targets.append(target_player)

	var parent_node := get_parent()
	if parent_node is MatchManager:
		var match_manager: MatchManager = parent_node
		if match_manager.player0 and not targets.has(match_manager.player0):
			targets.append(match_manager.player0)
		if match_manager.player1 and not targets.has(match_manager.player1):
			targets.append(match_manager.player1)

	return targets
