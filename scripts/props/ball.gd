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
var _was_on_ground: bool = false


func _ready() -> void:
	if not initial_velocity:
		push_warning("Ball: initial_velocity not set, using zero velocity")
		velocity = Vector3.ZERO
	else:
		velocity = initial_velocity

	if initial_position:
		global_position = initial_position
	else:
		push_warning("Ball: initial_position not set, using current position: ", global_position)


func _physics_process(delta: float) -> void:
	# Apply gravity with spin effect
	var gravity: float = GRAVITY_BASE + (spin * GameConstants.SPIN_GRAVITY_MULTIPLIER)
	velocity.y += -gravity * delta

	# Track previous velocity for bounce calculations
	if velocity.length() > GameConstants.VELOCITY_TRACKING_THRESHOLD:
		_previous_velocity = velocity

	move_and_slide()

	# Handle collisions
	if get_slide_collision_count() > 0:
		var collision: KinematicCollision3D = get_slide_collision(0)
		if not collision:
			push_warning("Ball: get_slide_collision(0) returned null despite collision count > 0")
			return

		var collider: Node = collision.get_collider()
		if not collider:
			push_warning("Ball: Collision detected but collider is null")
		elif collider.is_in_group("Net"):
			# Ball hit net - reduce velocity significantly
			_previous_velocity.z *= GameConstants.NET_BOUNCE_VELOCITY_DAMPING
			_previous_velocity.x *= GameConstants.NET_BOUNCE_VELOCITY_DAMPING
			velocity = _previous_velocity.bounce(collision.get_normal()) * BALL_DAMPING
			on_net.emit()
		else:
			# Ball hit ground - bounce with damping
			velocity = _previous_velocity.bounce(collision.get_normal()) * BALL_DAMPING
			position.y = BALL_GROUND_LEVEL

	# Emit ground signal only once per bounce (rising edge detection)
	var is_on_ground: bool = position.y < GameConstants.GROUND_EMISSION_THRESHOLD
	if is_on_ground and not _was_on_ground:
		on_ground.emit()
	_was_on_ground = is_on_ground

	# Apply air resistance
	velocity = velocity.lerp(Vector3.ZERO, GameConstants.AIR_RESISTANCE_FACTOR)


## Applies a stroke to the ball with given velocity and spin
func apply_stroke(stroke_velocity: Vector3, spin_amount: float) -> void:
	if not stroke_velocity:
		push_error("Ball.apply_stroke: stroke_velocity is null")
		return

	spin = spin_amount
	velocity = stroke_velocity


## Predicts ball trajectory for the next N steps
## Used by AI and aiming systems
func predict_trajectory(
	steps: int = GameConstants.TRAJECTORY_PREDICTION_STEPS,
	time_step: float = GameConstants.TRAJECTORY_TIME_STEP
) -> Array[TrajectoryStep]:
	# Validate parameters
	if steps <= 0:
		push_error("Ball.predict_trajectory: steps must be > 0, got: ", steps)
		return []

	if time_step <= 0.0:
		push_error("Ball.predict_trajectory: time_step must be > 0.0, got: ", time_step)
		return []

	var predicted_trajectory: Array[TrajectoryStep] = []
	var current_position: Vector3 = global_position
	var current_velocity: Vector3 = velocity
	var elapsed_time: float = 0.0
	var bounces := 0

	for _step_index in range(steps):
		# Apply gravity with spin effect
		var gravity: float = GRAVITY_BASE + (spin * GameConstants.SPIN_GRAVITY_MULTIPLIER)
		current_velocity.y += -gravity * time_step

		# Update position
		current_position += current_velocity * time_step


		# Simulate ground collision
		if current_position.y < BALL_GROUND_LEVEL:
			current_velocity = current_velocity.bounce(Vector3.UP) * BALL_DAMPING
			current_position.y = BALL_GROUND_LEVEL
			bounces += 1

		# Record trajectory point
		var trajectory_step: TrajectoryStep = TrajectoryStep.new(current_position, elapsed_time, bounces)
		predicted_trajectory.append(trajectory_step)

		elapsed_time += time_step

		# Stop if ball has essentially stopped
		if current_velocity.length() < GameConstants.TRAJECTORY_STOP_VELOCITY_THRESHOLD:
			break

	self.trajectory = predicted_trajectory
	return predicted_trajectory
