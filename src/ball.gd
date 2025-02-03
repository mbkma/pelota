class_name Ball
extends CharacterBody3D

signal on_ground

const DAMP := 0.7

var spin := 0.0

@export var initial_velocity: Vector3
@export var initial_position: Vector3

var trajectory := []


func _ready() -> void:
	velocity = initial_velocity
	position = initial_position


func spin_to_gravity(spin: float) -> float:
	return 10 + spin


func _process(delta: float) -> void:
	if velocity.length() > 0.01:  # Only predict if velocity is not almost zero
		trajectory = predict_trajectory()


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
	spin = _spin
	velocity = vel


func predict_trajectory(steps: int = 100, time_step: float = 0.016) -> Array:
	var trajectory := []
	var current_position = global_position
	var current_velocity = velocity

	for i in range(steps):
		# Calculate gravity based on spin
		var gravity = spin_to_gravity(spin)
		current_velocity.y += -gravity * time_step  # Apply gravity

		# Update position based on current velocity
		current_position += current_velocity * time_step

		# Simulate collisions with the ground
		if current_position.y < 0.035:  #FIXME: this is average pos ball at ground
			current_velocity = current_velocity.bounce(Vector3.UP) * DAMP

		# Add the current position to the trajectory
		trajectory.append(current_position)

		# Stop simulation if velocity is almost zero
		if current_velocity.length() < 0.01:
			break

	return trajectory
