extends Node3D

@onready var ball_spawn_marker_3d: Marker3D = $Marker3D
# Given parameters
@export var velocity_length: float = 10.0  # Example speed of the ball
@export var shoot_off_angle: float = 45.0  # Angle from the horizontal plane in degrees
@export var horizontal_angle: float = 0.0  # Angle in the horizontal plane in degrees


func _ready() -> void:
	print("ball machine global basis", global_basis)
	print("ball machine lokal basis", basis)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("request_ball"):
		# Convert angles to radians
		var shoot_off_angle_radians: float = deg_to_rad(shoot_off_angle)
		var horizontal_angle_radians: float = deg_to_rad(horizontal_angle)

		# Calculate the components of the initial velocity
		#var initial_velocity: Vector3 = Vector3(
			#velocity_length * cos(shoot_off_angle_radians) * sin(horizontal_angle_radians),
			#velocity_length * sin(shoot_off_angle_radians),
			#velocity_length * cos(shoot_off_angle_radians) * cos(horizontal_angle_radians)
		#)
		var initial_velocity = -global_basis.z.normalized() * velocity_length + global_basis.y.normalized() * shoot_off_angle


		var ball = GlobalUtils.BALL.instantiate()
		ball.initial_position = ball_spawn_marker_3d.global_position
		ball.initial_velocity = initial_velocity
		get_parent().add_child(ball)
		get_tree().call_group("Player", "set_active_ball", ball)
		ball.predict_trajectory()
