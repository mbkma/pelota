class_name Ball extends RigidBody3D

var velocity: Vector3
var spin: Vector3

@onready var game: Game = get_tree().root.get_node("Game")  # Adjust if necessary


func _integrate_forces(_state: PhysicsDirectBodyState3D):
	# Update ball physics based on velocity and spin
	if is_out_of_bounds():
		game.check_point(global_transform.origin)


func collide():
	# Logic for ball collision with players and court
	pass


func is_out_of_bounds() -> bool:
	return global_transform.origin.y <= 0  # Assuming y = 0 is the ground level
