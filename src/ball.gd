class_name Ball
extends CharacterBody3D

signal on_ground

const DAMP := 0.7
const GROUND := 0.035
var spin := 0.0

@export var initial_velocity: Vector3
var initial_position: Vector3

var trajectory := []


func _ready() -> void:
	print("ball global basis", global_basis)
	print("ball lokal basis", basis)
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
		velocity = prev_velocity.bounce(col.get_normal()) * DAMP
		position.y = GROUND
		if is_on_wall():
			velocity *= 0.05
		if position.y < 0.1:
			emit_signal("on_ground")

	#rotation = spin*velocity
	velocity = velocity.lerp(Vector3.ZERO, 0.001)

	#print("position", position)
	#print("global_position", global_position)
	#trajectory = predict_trajectory()

func apply_stroke(vel: Vector3, _spin: float) -> void:
	spin = _spin
	velocity = vel


func predict_trajectory(steps: int = 200, time_step: float = 0.016) -> Array:
	#print("global_position", global_position)
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
		if current_position.y < GROUND:  #FIXME: this is average pos ball at ground
			current_velocity = current_velocity.bounce(Vector3.UP) * DAMP
			current_position.y = GROUND
		# Add the current position to the trajectory
		trajectory.append(current_position)

		# Stop simulation if velocity is almost zero
		if current_velocity.length() < 0.01:
			break

	self.trajectory = trajectory
	#print(trajectory)

	return trajectory
