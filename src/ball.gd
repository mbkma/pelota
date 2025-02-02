class_name Ball
extends CharacterBody3D

signal on_ground

const DAMP := 0.7

var spin := 0.0

@export var initial_velocity: Vector3


func _ready() -> void:
	#velocity = initial_velocity
	apply_stroke(initial_velocity, 0)


func spin_to_gravity(spin: float) -> float:
	return 10 + spin


func _physics_process(delta: float) -> void:
	var gravity := spin_to_gravity(spin)
	velocity.y += -gravity * delta

	var prev_velocity = velocity
	move_and_slide()
	if get_slide_collision_count() > 0:
		var col := get_slide_collision(0)
		velocity = prev_velocity.bounce(col.get_normal())
		velocity *= DAMP
		if is_on_wall():
			velocity *= 0.05
		if position.y < 0.1:
			emit_signal("on_ground")

	#rotation = spin*velocity
	velocity = velocity.lerp(Vector3.ZERO, 0.001)


func apply_stroke(vel: Vector3, _spin: float) -> void:
	#print(predict_trajectory())
	spin = _spin
	velocity = vel


func predict_trajectory(steps: int = 100, time_step: float = 0.016) -> Array:
	var ghost_ball = duplicate()  # Create a copy of the ball
	get_parent().add_child(ghost_ball)
	#ghost_ball.set_script(null)  # Remove script to prevent physics conflicts
	ghost_ball.position = position
	ghost_ball.velocity = velocity
	ghost_ball.spin = spin

	var trajectory := []

	for i in range(steps):
		# Simulate physics step
		ghost_ball.velocity.y += -ghost_ball.spin_to_gravity(ghost_ball.spin) * time_step

		var prev_velocity = ghost_ball.velocity
		ghost_ball.position += ghost_ball.velocity * time_step  # Update position

		# Simulate collisions
		if ghost_ball.position.y < 0.1:
			ghost_ball.velocity = prev_velocity.bounce(Vector3.UP) * DAMP
			ghost_ball.position.y = 0.1  # Keep it above ground

		trajectory.append(ghost_ball.position)

		# Stop simulation if velocity is almost zero
		if ghost_ball.velocity.length() < 0.01:
			break

	# Clean up the ghost ball
	ghost_ball.queue_free()

	return trajectory
