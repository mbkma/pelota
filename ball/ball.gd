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
const TRAJECTORY_MAX_TIME: float = 5.0
const TRAJECTORY_SIMULATION_DT: float = 1.0 / 240.0

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


func _compute_magnus_force(spin_value: Vector3) -> Vector3:
	return Vector3(
		spin_value.x * SPIN_SIDE_MULT,
		-spin_value.y * SPIN_DOWN_FORCE,
		0.0
	)


func _apply_magnus_and_gravity(base_velocity: Vector3, spin_value: Vector3, delta: float) -> Vector3:
	var next_velocity: Vector3 = base_velocity
	var magnus_force: Vector3 = _compute_magnus_force(spin_value)
	next_velocity.y += (-GRAVITY_BASE + magnus_force.y) * delta
	next_velocity.x += magnus_force.x * delta
	next_velocity.z += magnus_force.z * delta
	return next_velocity


func _apply_air_drag(base_velocity: Vector3, delta: float) -> Vector3:
	var speed: float = base_velocity.length()
	if speed <= 0.0:
		return base_velocity

	# Quadratic drag is required for ball-like motion; linear drag under-damps and
	# causes visible re-acceleration late in flight.
	var delta_speed: float = AIR_DRAG * speed * speed * delta
	if delta_speed >= speed:
		return Vector3.ZERO

	return base_velocity * ((speed - delta_speed) / speed)


func _handle_collision(collision: KinematicCollision3D) -> void:
	if not collision:
		return

	var collider := collision.get_collider()
	if collider.name == "Net":
		Loggie.msg("Hit net!").debug()
		velocity = _previous_velocity.bounce(collision.get_normal()) * 0.1
		on_net.emit()
		return

	if collider.name == "Ground":
		Loggie.msg("Hit ground").debug()
		_realistic_bounce(collision)
		return

	velocity = _previous_velocity.bounce(collision.get_normal()) * 0.1
	Loggie.msg("Hit other object").debug()


func step(delta: float) -> void:
	# --- 1. Gravity + Magnus effect ---
	velocity = _apply_magnus_and_gravity(velocity, spin, delta)
	Loggie.msg("After gravity: velocity=", velocity).debug()

	# --- 2. Air drag ---
	velocity = _apply_air_drag(velocity, delta)
	Loggie.msg("After drag: velocity=", velocity).debug()

	_previous_velocity = velocity

	# --- 3. Move the ball ---
	move_and_slide()
	Loggie.msg("Moved to: ", global_position).debug()

	# --- 4. Handle collisions ---
	if get_slide_collision_count() > 0:
		var collision: KinematicCollision3D = get_slide_collision(0)
		Loggie.msg("Collision detected with: ", collision.get_collider()).debug()
		_handle_collision(collision)


	# --- 5. Ground signal ---
	var is_on_ground = position.y <= BALL_GROUND_LEVEL + 0.01
	if is_on_ground and not _was_on_ground:
		Loggie.msg("Ball hit ground at y=", position.y).debug()
		on_ground.emit()
	_was_on_ground = is_on_ground

func _realistic_bounce(collision: KinematicCollision3D) -> void:
	var normal: Vector3 = collision.get_normal()
	Loggie.msg("Collision normal: ", normal).debug()

	var v_normal = _previous_velocity.dot(normal) * normal
	var v_tangent = _previous_velocity - v_normal
	Loggie.msg("v_normal=", v_normal, " v_tangent=", v_tangent).debug()

	# Only bounce if normal velocity is significant
	if v_normal.length() < MIN_BOUNCE_SPEED:
		# Treat as rolling: keep XZ velocity, zero Y
		velocity.y = 0
		velocity.x *= BALL_DAMPING_HORIZONTAL
		velocity.z *= BALL_DAMPING_HORIZONTAL
		Loggie.msg("Rolling, no vertical bounce. New velocity=", velocity).debug()
		position.y = BALL_GROUND_LEVEL
		return

	var bounce_normal = -v_normal * BALL_DAMPING_VERTICAL
	var bounce_tangent = v_tangent * BALL_DAMPING_HORIZONTAL
	bounce_tangent.x += spin.x * SPIN_SIDE_MULT

	velocity = bounce_normal + bounce_tangent
	Loggie.msg("New velocity after bounce: ", velocity).debug()

	position.y = max(position.y, BALL_GROUND_LEVEL + 0.001)
	Loggie.msg("Corrected position.y=", position.y).debug()


func simulate_trajectory(start_position: Vector3, v0: Vector3, spin_value: Vector3) -> Vector3:
	var pos: Vector3 = start_position
	var vel: Vector3 = v0
	var t := 0.0
	var dt := TRAJECTORY_SIMULATION_DT

	while t < TRAJECTORY_MAX_TIME:
		# --- Compute forces ---
		vel = _apply_magnus_and_gravity(vel, spin_value, dt)
		vel = _apply_air_drag(vel, dt)

		# integrate
		pos += vel * dt
		
		if pos.y <= BALL_GROUND_LEVEL:
			return pos  # return landing position

		t += dt

	return pos  # fallback


func calculate_velocity(
	start_position: Vector3, target_position: Vector3, velocity_z0: float, spin_value: Vector3
) -> Vector3:
	var vx0 := 0.0
	var vy0 := 0.0
	var learning_rate: float = 0.2

	var landed: Vector3 = start_position
	for _iteration in 8:
		var v0: Vector3 = Vector3(vx0, vy0, velocity_z0)
		landed = simulate_trajectory(start_position, v0, spin_value)

		var error_x: float = target_position.x - landed.x
		var error_z: float = target_position.z - landed.z

		if abs(error_x) < 0.05 and abs(error_z) < 0.05:
			break

		# adjust vx and vy
		# vy0 affects flight time, which affects Z distance traveled
		# The relationship depends on the sign of velocity_z0
		vx0 += error_x * learning_rate
		vy0 += sign(velocity_z0) * error_z * learning_rate

	return Vector3(vx0, vy0, velocity_z0)


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
		# Keep prediction in lockstep with runtime ball physics.
		current_velocity = _apply_magnus_and_gravity(current_velocity, spin, time_step)
		current_velocity = _apply_air_drag(current_velocity, time_step)

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

	return bounce_normal + bounce_tangent
