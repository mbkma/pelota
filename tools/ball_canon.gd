extends Node3D

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
	_ball_factory = BallFactory.new(ball_scene)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("request_ball"):
		# Calculate launch velocity from explicit horizontal and elevation angles.
		var _shoot_off_angle_radians: float = deg_to_rad(shoot_off_angle)
		var _horizontal_angle_radians: float = deg_to_rad(horizontal_angle)

		var forward_flat: Vector3 = -global_basis.z
		forward_flat.y = 0.0
		if forward_flat.length() == 0:
			forward_flat = Vector3.FORWARD
		else:
			forward_flat = forward_flat.normalized()

		var horizontal_basis := Basis(Vector3.UP, _horizontal_angle_radians)
		var launch_direction_flat: Vector3 = (horizontal_basis * forward_flat).normalized()

		var horizontal_speed: float = cos(_shoot_off_angle_radians) * velocity_length
		var vertical_speed: float = sin(_shoot_off_angle_radians) * velocity_length
		var initial_velocity: Vector3 = launch_direction_flat * horizontal_speed + Vector3.UP * vertical_speed

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
