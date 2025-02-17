class_name Ball
extends CharacterBody3D

signal on_ground
signal on_net

const DAMP := 0.7
const GROUND := 0.035
var spin := 0.0

@export var initial_velocity: Vector3
var initial_position: Vector3

var trajectory := []


func _ready() -> void:
	velocity = initial_velocity
	if initial_position:
		global_position = initial_position


func spin_to_gravity(spin: float) -> float:
	return 10 + spin


var prev_velocity


func _physics_process(delta: float) -> void:
	var gravity := spin_to_gravity(spin)
	velocity.y += -gravity * delta

	if velocity.length() > 0.1:
		prev_velocity = velocity
	move_and_slide()
	if get_slide_collision_count() > 0:
		var col := get_slide_collision(0)
		var collider := col.get_collider()
		if collider.is_in_group("Net"):
			prev_velocity.z *= 0.1
			prev_velocity.x *= 0.1
			velocity = prev_velocity.bounce(col.get_normal()) * DAMP
			on_net.emit()
		else:
			velocity = prev_velocity.bounce(col.get_normal()) * DAMP
			position.y = GROUND
		if position.y < 0.1:
			on_ground.emit()

	#rotation = spin*velocity
	velocity = velocity.lerp(Vector3.ZERO, 0.001)

	#print("position", position)
	#print("global_position", global_position)
	#trajectory = predict_trajectory()


func apply_stroke(vel: Vector3, _spin: float) -> void:
	spin = _spin
	velocity = vel


func predict_trajectory(steps: int = 200, time_step: float = 0.016) -> Array[TrajectoryStep]:
	#print("global_position", global_position)
	var trajectory: Array[TrajectoryStep]
	var current_position = global_position
	var current_velocity = velocity

	var time := 0.0
	for i in range(steps):
		# Calculate gravity based on spin
		var gravity = spin_to_gravity(spin)
		current_velocity.y += -gravity * time_step  # Apply gravity
		# Update position based on current velocity
		current_position += current_velocity * time_step

		# Simulate collisions with the ground
		if current_position.y < GROUND:  #FIXME: this is average pos ball at ground
			current_velocity = current_velocity.bounce(Vector3.UP) * DAMP
			current_position.y = GROUND
		# Add the current position to the trajectory
		var step = TrajectoryStep.new(current_position, time)
		trajectory.append(step)
		time += time_step
		# Stop simulation if velocity is almost zero
		if current_velocity.length() < 0.01:
			break

	self.trajectory = trajectory
	#print(trajectory)

	return trajectory
