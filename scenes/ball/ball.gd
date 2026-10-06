## Physics-based ball entity with trajectory prediction and collision handling

class_name Ball
extends CharacterBody3D

signal on_ground
signal on_net

const BALL_GROUND_LEVEL: float = GameConstants.BALL_GROUND_THRESHOLD
const GRAVITY_BASE: float = GameConstants.GRAVITY

# Bounce & friction constants
const BALL_DAMPING: float = 0.7
const BALL_DAMPING_VERTICAL: float = 0.7
const BALL_DAMPING_HORIZONTAL: float = 0.9
const MIN_BOUNCE_SPEED = 0.2  # tweak to taste

# Spin effect multipliers
const TOPSPIN_ACCEL_MAX: float = 15.0
const SIDESPIN_ACCEL_MAX: float = 8.0
# Spin effect on the bounce: topspin kicks the ball higher, backspin keeps it low,
# sidespin kicks it sideways (m/s at full sidespin).
const SPIN_BOUNCE_LIFT: float = 0.25
const SPIN_BOUNCE_SIDE_KICK: float = 2.0

# Air resistance
const AIR_DRAG: float = 0.02
const TRAJECTORY_MAX_TIME: float = 5.0
const TRAJECTORY_SIMULATION_DT: float = 1.0 / 240.0
# Velocity solver: landing tolerance (m), vertical speed probe and step limit (m/s)
const VELOCITY_SOLVER_MAX_ITERATIONS: int = 12
const VELOCITY_SOLVER_TOLERANCE: float = 0.03
const VELOCITY_SOLVER_PROBE: float = 0.5
const VELOCITY_SOLVER_MAX_STEP: float = 6.0

@export var initial_velocity: Vector3

var trajectory: Array[TrajectoryStep] = []
var initial_position: Vector3

# x: sidespin, y: topspin/backspin - 1.0 heavy top spin, -1.0 heavy underspin
var spin: Vector3 = Vector3.ZERO
var _previous_velocity: Vector3 = Vector3.ZERO
var _was_on_ground: bool = false


func _ready() -> void:
	set_meta("logger_name", "Ball")

	if initial_velocity:
		velocity = initial_velocity
	else:
		velocity = Vector3.ZERO

	if initial_position:
		global_position = initial_position


func _physics_process(delta: float) -> void:
	step(delta)


func _compute_sidespin_direction(base_velocity: Vector3) -> Vector3:
	var horizontal_velocity := Vector3(base_velocity.x, 0.0, base_velocity.z)
	if horizontal_velocity.length_squared() <= 0.0001:
		return Vector3.RIGHT

	var forward := horizontal_velocity.normalized()
	return Vector3.UP.cross(forward).normalized()


func _compute_spin_force(base_velocity: Vector3, spin_value: Vector3) -> Vector3:
	var speed: float = base_velocity.length()

	# Scale spin effect with shot speed.
	var speed_factor: float = min(speed / 40.0, 1.0)
	var sidespin_direction := _compute_sidespin_direction(base_velocity)

	return (
		sidespin_direction * (spin_value.x * SIDESPIN_ACCEL_MAX * speed_factor)
		+ Vector3(0.0, -spin_value.y * TOPSPIN_ACCEL_MAX * speed_factor, 0.0)
	)


func _advance_velocity(base_velocity: Vector3, spin_value: Vector3, delta: float) -> Vector3:
	var next_velocity: Vector3 = base_velocity
	var spin_force: Vector3 = _compute_spin_force(base_velocity, spin_value)
	next_velocity.x += spin_force.x * delta
	next_velocity.y += (-GRAVITY_BASE + spin_force.y) * delta
	return _apply_air_drag(next_velocity, delta)


func _apply_air_drag(base_velocity: Vector3, delta: float) -> Vector3:
	var speed := base_velocity.length()
	if speed <= 0.0:
		return base_velocity

	var factor := 1.0 / (1.0 + AIR_DRAG * speed * delta)
	return base_velocity * factor


func _handle_collision(collision: KinematicCollision3D) -> void:
	if not collision:
		return

	var collider := collision.get_collider()
	if collider.name == "Net":
		velocity = _previous_velocity.bounce(collision.get_normal()) * 0.1
		on_net.emit()
		return

	if collider.name == "Ground":
		_realistic_bounce(collision)
		return

	velocity = _previous_velocity.bounce(collision.get_normal()) * 0.1


func step(delta: float) -> void:
	# --- 1. Gravity + Spin effect ---
	velocity = _advance_velocity(velocity, spin, delta)

	_previous_velocity = velocity

	# --- 3. Move the ball ---
	move_and_slide()

	# --- 4. Handle collisions ---
	if get_slide_collision_count() > 0:
		var collision: KinematicCollision3D = get_slide_collision(0)
		_handle_collision(collision)

	# --- 5. Ground signal ---
	var is_on_ground = position.y <= BALL_GROUND_LEVEL + 0.01
	if is_on_ground and not _was_on_ground:
		on_ground.emit()
	_was_on_ground = is_on_ground


func _compute_bounce_velocity(prev_velocity: Vector3, spin_value: Vector3) -> Vector3:
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

	var spin_lift: float = 1.0 + spin_value.y * SPIN_BOUNCE_LIFT
	var bounce_normal = -v_normal * BALL_DAMPING_VERTICAL * spin_lift
	var bounce_tangent = v_tangent * BALL_DAMPING_HORIZONTAL
	var side_kick: Vector3 = (
		_compute_sidespin_direction(prev_velocity) * spin_value.x * SPIN_BOUNCE_SIDE_KICK
	)
	return bounce_normal + bounce_tangent + side_kick


func _realistic_bounce(collision: KinematicCollision3D) -> void:
	var normal: Vector3 = collision.get_normal()

	var v_normal = _previous_velocity.dot(normal) * normal

	# Only bounce if normal velocity is significant
	if v_normal.length() < MIN_BOUNCE_SPEED:
		# Treat as rolling: keep XZ velocity, zero Y
		velocity.y = 0
		velocity.x *= BALL_DAMPING_HORIZONTAL
		velocity.z *= BALL_DAMPING_HORIZONTAL
		position.y = BALL_GROUND_LEVEL
		return

	velocity = _compute_bounce_velocity(_previous_velocity, spin)

	position.y = max(position.y, BALL_GROUND_LEVEL + 0.001)


## First step of a trajectory that touches the ground (or the last step if none does).
func _first_landing_step(predicted_trajectory: Array[TrajectoryStep]) -> TrajectoryStep:
	for trajectory_step in predicted_trajectory:
		if trajectory_step.bounces > 0 or trajectory_step.point.y <= BALL_GROUND_LEVEL:
			return trajectory_step
	return predicted_trajectory[-1]


## Where and when a ball hit from `start_position` with `start_velocity` first lands.
func _simulate_landing(
	start_position: Vector3, start_velocity: Vector3, spin_value: Vector3
) -> TrajectoryStep:
	var predicted_trajectory := predict_trajectory(
		ceili(TRAJECTORY_MAX_TIME / TRAJECTORY_SIMULATION_DT),
		TRAJECTORY_SIMULATION_DT,
		{
			"position": start_position,
			"velocity": start_velocity,
			"spin": spin_value,
			"store_result": false,
		}
	)
	return _first_landing_step(predicted_trajectory)


## Velocity that makes a ball with the given forward speed and spin land on `target_position`.
## The sideways speed is corrected by the landing error over the flight time; the vertical
## speed by the landing depth error over the measured depth change per m/s of vertical speed.
func calculate_velocity(
	start_position: Vector3, target_position: Vector3, velocity_z0: float, spin_value: Vector3
) -> Vector3:
	var distance_z: float = maxf(absf(target_position.z - start_position.z), 0.1)
	var vx0: float = (target_position.x - start_position.x) * absf(velocity_z0) / distance_z
	var vy0: float = 0.0

	for _iteration in range(VELOCITY_SOLVER_MAX_ITERATIONS):
		var landing: TrajectoryStep = _simulate_landing(
			start_position, Vector3(vx0, vy0, velocity_z0), spin_value
		)
		var error_x: float = target_position.x - landing.point.x
		var error_z: float = target_position.z - landing.point.z
		if (
			absf(error_x) < VELOCITY_SOLVER_TOLERANCE
			and absf(error_z) < VELOCITY_SOLVER_TOLERANCE
		):
			break

		vx0 += error_x / maxf(landing.time, 0.05)

		var probe: TrajectoryStep = _simulate_landing(
			start_position, Vector3(vx0, vy0 + VELOCITY_SOLVER_PROBE, velocity_z0), spin_value
		)
		var depth_per_vy: float = (probe.point.z - landing.point.z) / VELOCITY_SOLVER_PROBE
		if absf(depth_per_vy) > 0.01:
			vy0 += clampf(
				error_z / depth_per_vy, -VELOCITY_SOLVER_MAX_STEP, VELOCITY_SOLVER_MAX_STEP
			)

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
	time_step: float = GameConstants.TRAJECTORY_TIME_STEP,
	options: Dictionary = {}
) -> Array[TrajectoryStep]:
	# Validate parameters
	if steps <= 0:
		push_error("Ball.predict_trajectory: steps must be > 0, got: ", steps)
		return []

	if time_step <= 0.0:
		push_error("Ball.predict_trajectory: time_step must be > 0.0, got: ", time_step)
		return []

	var predicted_trajectory: Array[TrajectoryStep] = []
	var current_position: Vector3 = options.get("position", global_position)
	var current_velocity: Vector3 = options.get("velocity", velocity)
	var current_spin: Vector3 = options.get("spin", spin)
	var store_result: bool = options.get("store_result", true)
	var elapsed_time: float = 0.0
	var bounces := 0

	for _step_index in range(steps):
		# Keep prediction in lockstep with runtime ball physics.
		current_velocity = _advance_velocity(current_velocity, current_spin, time_step)

		# --- 3. Update position ---
		current_position += current_velocity * time_step
		elapsed_time += time_step

		# --- 4. Simulate ground collision using the same physics as real bounces ---
		if current_position.y < BALL_GROUND_LEVEL:
			current_velocity = _compute_bounce_velocity(current_velocity, current_spin)
			current_position.y = BALL_GROUND_LEVEL
			bounces += 1

		# --- 5. Record trajectory point ---
		var trajectory_step: TrajectoryStep = TrajectoryStep.new(
			current_position, elapsed_time, bounces
		)
		predicted_trajectory.append(trajectory_step)

		# --- 6. Stop if ball has essentially stopped ---
		if current_velocity.length() < GameConstants.TRAJECTORY_STOP_VELOCITY_THRESHOLD:
			break

	if store_result:
		self.trajectory = predicted_trajectory
	return predicted_trajectory
