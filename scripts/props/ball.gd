## Physics-based ball entity with trajectory prediction and collision handling

class_name Ball
extends CharacterBody3D

signal on_ground
signal on_net

var trajectory: Array[TrajectoryStep] = []

const BALL_GROUND_LEVEL: float = GameConstants.BALL_GROUND_THRESHOLD
const GRAVITY_BASE: float = GameConstants.GRAVITY

# Bounce & friction constants
const BALL_DAMPING: float = 0.7
const BALL_DAMPING_VERTICAL: float = 0.7
const BALL_DAMPING_HORIZONTAL: float = 0.9
const MIN_BOUNCE_SPEED = 0.2  # tweak to taste
# Spin effect multipliers
const SPIN_FORWARD_MULT: float = 0.12
const SPIN_SIDE_MULT: float = 0.08
const SPIN_DOWN_FORCE: float = 0.1

# Air resistance
const AIR_DRAG: float = 0.02

@export var initial_velocity: Vector3
var initial_position: Vector3

var spin: Vector3 = Vector3.ZERO  # x: sidespin, y: topspin/backspin, z: forward spin
var _previous_velocity: Vector3 = Vector3.ZERO
var _was_on_ground: bool = false

func _ready() -> void:
	if initial_velocity:
		velocity = initial_velocity
	else:
		velocity = Vector3.ZERO

	if initial_position:
		global_position = initial_position

func _physics_process(delta: float) -> void:
	step(delta)

func step(delta: float) -> void:
	# --- 1. Gravity + Magnus effect ---
	var magnus_force = Vector3(
		spin.x * SPIN_SIDE_MULT,
		-spin.y * SPIN_DOWN_FORCE,
		spin.z * SPIN_FORWARD_MULT
	)
	velocity.y += (-GRAVITY_BASE + magnus_force.y) * delta
	velocity.x += magnus_force.x * delta
	velocity.z += magnus_force.z * delta
	print("[Physics] After gravity: velocity=", velocity)

	# --- 2. Air drag ---
	velocity -= velocity * AIR_DRAG * delta
	print("[Physics] After drag: velocity=", velocity)

	_previous_velocity = velocity

	# --- 3. Move the ball ---
	move_and_slide()
	print("[Physics] Moved to: ", global_position)

	# --- 4. Handle collisions ---
	if get_slide_collision_count() > 0:
		var collision: KinematicCollision3D = get_slide_collision(0)
		print("[Collision] Collision detected with: ", collision.get_collider())
		if collision:
			var collider := collision.get_collider()
			if collider.name == "Net":
				print("[Collision] Hit net!")
				velocity = _previous_velocity.bounce(collision.get_normal()) * 0.1
				on_net.emit()
			elif collider.name == "Ground":
				print("[Collision] Hit ground")
				_realistic_bounce(collision)
			else:
				velocity = _previous_velocity.bounce(collision.get_normal()) * 0.1
				print("[Collision] Hit other object")


	# --- 5. Ground signal ---
	var is_on_ground = position.y <= BALL_GROUND_LEVEL + 0.01
	if is_on_ground and not _was_on_ground:
		print("[Ground] Ball hit ground at y=", position.y)
		on_ground.emit()
	_was_on_ground = is_on_ground

func _realistic_bounce(collision: KinematicCollision3D) -> void:
	var normal: Vector3 = collision.get_normal()
	print("[Bounce] Collision normal: ", normal)

	var v_normal = _previous_velocity.dot(normal) * normal
	var v_tangent = _previous_velocity - v_normal
	print("[Bounce] v_normal=", v_normal, " v_tangent=", v_tangent)

	# Only bounce if normal velocity is significant
	if v_normal.length() < MIN_BOUNCE_SPEED:
		# Treat as rolling: keep XZ velocity, zero Y
		velocity.y = 0
		velocity.x *= BALL_DAMPING_HORIZONTAL
		velocity.z *= BALL_DAMPING_HORIZONTAL
		print("[Bounce] Rolling, no vertical bounce. New velocity=", velocity)
		position.y = BALL_GROUND_LEVEL
		return

	var bounce_normal = -v_normal * BALL_DAMPING_VERTICAL
	var bounce_tangent = v_tangent * BALL_DAMPING_HORIZONTAL
	bounce_tangent.x += spin.x * SPIN_SIDE_MULT
	bounce_tangent.z += spin.z * SPIN_FORWARD_MULT

	velocity = bounce_normal + bounce_tangent
	print("[Bounce] New velocity after bounce: ", velocity)

	position.y = max(position.y, BALL_GROUND_LEVEL + 0.001)
	print("[Bounce] Corrected position.y=", position.y)


## Calculates required velocity x,y components to hit ball from initial position to target, given the initial z velocity component
## Accounts for Magnus effect, air drag, and gravity
func calculate_velocity(
	start_position: Vector3, target_position: Vector3, velocity_z0: float, ball_spin: Vector3
) -> Vector3:
	var calculated_velocity: Vector3 = Vector3.ZERO

	# Initial estimate using simple ballistics
	var time_to_target: float = (target_position.z - start_position.z) / velocity_z0
	calculated_velocity.x = (target_position.x - start_position.x) / time_to_target
	calculated_velocity.y = (
		(0.5 * GRAVITY_BASE * time_to_target * time_to_target + (target_position.y - start_position.y)) / time_to_target
	)
	calculated_velocity.z = velocity_z0

	return calculated_velocity


## Applies a stroke to the ball with given velocity and spin
func apply_stroke(stroke_velocity: Vector3, spin_amount: Vector3) -> void:
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
		# --- 1. Apply gravity with spin effect ---
		var magnus_force = Vector3(
			spin.x * SPIN_SIDE_MULT,
			-spin.y * SPIN_DOWN_FORCE,
			spin.z * SPIN_FORWARD_MULT
		)
		current_velocity.y += (-GRAVITY_BASE + magnus_force.y) * time_step
		current_velocity.x += magnus_force.x * time_step
		current_velocity.z += magnus_force.z * time_step

		# --- 2. Apply air drag ---
		current_velocity -= current_velocity * AIR_DRAG * time_step

		# --- 3. Update position ---
		current_position += current_velocity * time_step

		# --- 4. Simulate ground collision using the same physics as real bounces ---
		if current_position.y < BALL_GROUND_LEVEL:
			current_velocity = _simulate_bounce(current_velocity)
			current_position.y = BALL_GROUND_LEVEL
			bounces += 1

		# --- 5. Record trajectory point ---
		var trajectory_step: TrajectoryStep = TrajectoryStep.new(current_position, elapsed_time, bounces)
		predicted_trajectory.append(trajectory_step)

		elapsed_time += time_step

		# --- 6. Stop if ball has essentially stopped ---
		if current_velocity.length() < GameConstants.TRAJECTORY_STOP_VELOCITY_THRESHOLD:
			break

	self.trajectory = predicted_trajectory
	return predicted_trajectory

## Simulates a ground bounce and returns the new velocity
## Used for trajectory prediction without side effects
func _simulate_bounce(prev_velocity: Vector3) -> Vector3:
	var normal: Vector3 = Vector3.UP

	var v_normal = prev_velocity.dot(normal) * normal
	var v_tangent = prev_velocity - v_normal

	# Only bounce if normal velocity is significant
	if v_normal.length() < MIN_BOUNCE_SPEED:
		# Treat as rolling: keep XZ velocity, zero Y
		var rolling_vel = prev_velocity
		rolling_vel.y = 0
		rolling_vel.x *= BALL_DAMPING_HORIZONTAL
		rolling_vel.z *= BALL_DAMPING_HORIZONTAL
		return rolling_vel

	var bounce_normal = -v_normal * BALL_DAMPING_VERTICAL
	var bounce_tangent = v_tangent * BALL_DAMPING_HORIZONTAL
	bounce_tangent.x += spin.x * SPIN_SIDE_MULT
	bounce_tangent.z += spin.z * SPIN_FORWARD_MULT

	return bounce_normal + bounce_tangent
