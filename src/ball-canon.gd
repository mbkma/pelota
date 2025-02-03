extends Node3D

@onready var ball_spawn_marker_3d: Marker3D = $Marker3D
@export var initial_velocity := Vector3(0, 2, 20)


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("request_ball"):
		var ball = GlobalUtils.BALL.instantiate()
		#add_child(ball)
		ball.initial_position = ball_spawn_marker_3d.position
		ball.initial_velocity = (
			initial_velocity + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
		)
		add_child(ball)
		get_tree().call_group("Player", "set_active_ball", ball)
