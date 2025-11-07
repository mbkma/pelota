## Physics-based ball entity with trajectory prediction and collision handling
class_name Ball
extends CharacterBody3D

signal on_ground
signal on_net

const BALL_DAMPING: float = GameConstants.BALL_DAMP
const BALL_GROUND_LEVEL: float = GameConstants.BALL_GROUND_THRESHOLD
const GRAVITY_BASE: float = GameConstants.GRAVITY

@export var initial_velocity: Vector3
var initial_position: Vector3

var spin: float = 0.0
var trajectory: Array[TrajectoryStep] = []
var _previous_velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	velocity = initial_velocity
	if initial_position:
		global_position = initial_position


func _physics_process(delta: float) -> void:
	# Apply gravity with spin effect
	var gravity: float = GRAVITY_BASE + (spin * 0.5)
	velocity.y += -gravity * delta

	# Track previous velocity for bounce calculations
	if velocity.length() > 0.1:
		_previous_velocity = velocity

	move_and_slide()

	# Handle collisions
	if get_slide_collision_count() > 0:
		var collision: KinematicCollision3D = get_slide_collision(0)
		var collider: Node = collision.get_collider()

		if collider.is_in_group("Net"):
			# Ball hit net - reduce velocity significantly
			_previous_velocity.z *= 0.1
			_previous_velocity.x *= 0.1
			velocity = _previous_velocity.bounce(collision.get_normal()) * BALL_DAMPING
			on_net.emit()
		else:
			# Ball hit ground - bounce with damping
			velocity = _previous_velocity.bounce(collision.get_normal()) * BALL_DAMPING
			position.y = BALL_GROUND_LEVEL

		# Emit ground signal if ball is near ground level
		if position.y < 0.1:
			on_ground.emit()

	# Apply air resistance
	velocity = velocity.lerp(Vector3.ZERO, 0.001)


## Applies a stroke to the ball with given velocity and spin
func apply_stroke(stroke_velocity: Vector3, spin_amount: float) -> void:
	spin = spin_amount
	velocity = stroke_velocity


## Predicts ball trajectory for the next N steps
## Used by AI and aiming systems
func predict_trajectory(
	steps: int = 200,
	time_step: float = 0.016
) -> Array[TrajectoryStep]:
	var predicted_trajectory: Array[TrajectoryStep] = []
	var current_position: Vector3 = global_position
	var current_velocity: Vector3 = velocity
	var elapsed_time: float = 0.0

	for _step_index in range(steps):
		# Apply gravity with spin effect
		var gravity: float = GRAVITY_BASE + (spin * 0.5)
		current_velocity.y += -gravity * time_step

		# Update position
		current_position += current_velocity * time_step

		# Simulate ground collision
		if current_position.y < BALL_GROUND_LEVEL:
			current_velocity = current_velocity.bounce(Vector3.UP) * BALL_DAMPING
			current_position.y = BALL_GROUND_LEVEL

		# Record trajectory point
		var trajectory_step: TrajectoryStep = TrajectoryStep.new(current_position, elapsed_time)
		predicted_trajectory.append(trajectory_step)

		elapsed_time += time_step

		# Stop if ball has essentially stopped
		if current_velocity.length() < 0.01:
			break

	self.trajectory = predicted_trajectory
	return predicted_trajectory
