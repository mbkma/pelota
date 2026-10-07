## Tennis ball with analytic flight, bounce, roll and net physics.
## The ball and its trajectory prediction run the same simulation step, so predicted and real
## flight match. Only the stadium walls use the physics engine; the ground, the net and the
## players are excluded from physics collisions (the ground and net are simulated
## analytically), so the ball cannot snag on them.
class_name Ball
extends CharacterBody3D

## Emitted when the ball touches the ground (each bounce, and once when it starts rolling)
signal on_ground
## Emitted when the ball runs into the net and drops back on the hitter's side
signal on_net
## Emitted when the ball clips the net cord and still goes over
signal on_net_cord

## Result of a simulation step
enum StepEvent { NONE, BOUNCED, ROLLING_STARTED, HIT_NET, CLIPPED_NET_CORD }

const RADIUS: float = 0.033
const GRAVITY: float = GameConstants.GRAVITY

# Air
const AIR_DRAG: float = 0.02
const TOPSPIN_ACCEL_MAX: float = 15.0
const SIDESPIN_ACCEL_MAX: float = 8.0

# Ground: share of the vertical speed kept by a bounce (gentle impacts keep more than hard
# ones, up to the impact speed BOUNCE_HARD_IMPACT_SPEED), share of the horizontal speed kept by
# the friction of a bounce, and the vertical impact speed below which the ball rolls instead.
const BOUNCE_RESTITUTION_SOFT: float = 0.78
const BOUNCE_RESTITUTION_HARD: float = 0.6
const BOUNCE_HARD_IMPACT_SPEED: float = 12.0
const BOUNCE_HORIZONTAL_RETENTION: float = 0.88
const ROLL_SPEED_THRESHOLD: float = 0.6
# Spin on the bounce: topspin kicks the ball higher and forward, backspin keeps it low and
# checks it, sidespin kicks it sideways (m/s at full spin and a ball of SPIN_KICK_FULL_SPEED).
const SPIN_BOUNCE_LIFT: float = 0.2
const SPIN_BOUNCE_FORWARD_KICK: float = 1.5
const SPIN_BOUNCE_SIDE_KICK: float = 2.0
const SPIN_RETENTION_ON_BOUNCE: float = 0.6
const SPIN_KICK_FULL_SPEED: float = 20.0
# Rolling deceleration (m/s²)
const ROLL_DECELERATION: float = 1.5

# Net: the cord sags from NET_POST_HEIGHT at the singles sticks to NET_CENTER_HEIGHT.
const NET_CENTER_HEIGHT: float = 0.914
const NET_POST_HEIGHT: float = 1.065
const NET_HALF_WIDTH: float = 4.97
# Share of the speed a ball keeps after clipping the cord, and after running into the net.
const NET_CORD_SPEED_RETENTION: float = 0.45
const NET_REBOUND: float = 0.1

# Walls (physics engine): share of the speed kept by a wall bounce
const WALL_BOUNCE_RETENTION: float = 0.3

const TRAJECTORY_MAX_TIME: float = 5.0
const TRAJECTORY_SIMULATION_DT: float = 1.0 / 240.0
# Velocity solver: landing tolerance (m), vertical speed probe and step limit (m/s)
const VELOCITY_SOLVER_MAX_ITERATIONS: int = 12
const VELOCITY_SOLVER_TOLERANCE: float = 0.03
const VELOCITY_SOLVER_PROBE: float = 0.5
const VELOCITY_SOLVER_MAX_STEP: float = 6.0
# Net clearance: a shot that would pass the cord lower than the requested clearance is hit
# slower (with a higher arc) by this factor, up to this many times.
const NET_CLEARANCE_SPEED_FACTOR: float = 0.9
const NET_CLEARANCE_MAX_ATTEMPTS: int = 8


## Simulated ball state for one step.
class State:
	var position: Vector3
	var velocity: Vector3
	var spin: Vector3
	var rolling: bool = false

	func _init(p_position: Vector3, p_velocity: Vector3, p_spin: Vector3, p_rolling: bool) -> void:
		position = p_position
		velocity = p_velocity
		spin = p_spin
		rolling = p_rolling


var initial_position: Vector3
var initial_velocity: Vector3
## Last predicted trajectory of the ball itself (see predict_trajectory)
var trajectory: Array[TrajectoryStep] = []

# x: sidespin, y: topspin/backspin - 1.0 heavy top spin, -1.0 heavy underspin
var spin: Vector3 = Vector3.ZERO
## Ground contacts since the last stroke; predicted trajectory steps count on from it.
var bounces_since_stroke: int = 0
var _rolling: bool = false


func _ready() -> void:
	set_meta("logger_name", "Ball")
	velocity = initial_velocity
	global_position = initial_position
	for group in ["Ground", "Net", "Players"]:
		for body in get_tree().get_nodes_in_group(group):
			add_collision_exception_with(body)


func _physics_process(delta: float) -> void:
	var state := State.new(global_position, velocity, spin, _rolling)
	var event: StepEvent = _simulate_step(state, delta)

	# Walls are the only obstacles left to the physics engine.
	var collision: KinematicCollision3D = move_and_collide(state.position - global_position)
	if collision:
		state.velocity = state.velocity.bounce(collision.get_normal()) * WALL_BOUNCE_RETENTION

	velocity = state.velocity
	spin = state.spin
	_rolling = state.rolling

	match event:
		StepEvent.BOUNCED, StepEvent.ROLLING_STARTED:
			bounces_since_stroke += 1
			on_ground.emit()
		StepEvent.HIT_NET:
			on_net.emit()
		StepEvent.CLIPPED_NET_CORD:
			on_net_cord.emit()


## Applies a stroke to the ball with given velocity and spin
func apply_stroke(stroke_velocity: Vector3, spin_amount: Vector3) -> void:
	spin = spin_amount.clamp(-Vector3.ONE, Vector3.ONE)
	velocity = stroke_velocity
	_rolling = false
	bounces_since_stroke = 0


## Height of the net cord at `x`, or -INF outside the net posts.
static func net_height(x: float) -> float:
	if absf(x) > NET_HALF_WIDTH:
		return -INF
	return lerpf(NET_CENTER_HEIGHT, NET_POST_HEIGHT, absf(x) / NET_HALF_WIDTH)


## Advances `state` by `delta`: flight with gravity, spin and drag, ground bounces and
## rolling, and the net. Shared by the ball and its trajectory prediction.
func _simulate_step(state: State, delta: float, with_net: bool = true) -> StepEvent:
	if state.rolling:
		_roll(state, delta)
		return StepEvent.NONE

	var previous_position: Vector3 = state.position
	state.velocity = _advance_velocity(state.velocity, state.spin, delta)
	state.position += state.velocity * delta

	if with_net:
		var net_event: StepEvent = _collide_with_net(state, previous_position)
		if net_event != StepEvent.NONE:
			return net_event

	if state.position.y < RADIUS:
		return _touch_ground(state)
	return StepEvent.NONE


func _advance_velocity(base_velocity: Vector3, spin_value: Vector3, delta: float) -> Vector3:
	var next_velocity: Vector3 = (
		base_velocity + _compute_spin_force(base_velocity, spin_value) * delta
	)
	next_velocity.y -= GRAVITY * delta
	return next_velocity / (1.0 + AIR_DRAG * next_velocity.length() * delta)


func _compute_spin_force(base_velocity: Vector3, spin_value: Vector3) -> Vector3:
	# Spin acts more on fast balls.
	var speed_factor: float = minf(base_velocity.length() / 40.0, 1.0)
	return (
		_sidespin_direction(base_velocity) * (spin_value.x * SIDESPIN_ACCEL_MAX * speed_factor)
		+ Vector3(0.0, -spin_value.y * TOPSPIN_ACCEL_MAX * speed_factor, 0.0)
	)


## Horizontal direction a positive sidespin pushes the ball (to the hitter's left).
func _sidespin_direction(base_velocity: Vector3) -> Vector3:
	var horizontal := Vector3(base_velocity.x, 0.0, base_velocity.z)
	if horizontal.length_squared() <= 0.0001:
		return Vector3.RIGHT
	return Vector3.UP.cross(horizontal.normalized()).normalized()


func _touch_ground(state: State) -> StepEvent:
	state.position.y = RADIUS
	var impact_speed: float = -state.velocity.y
	if impact_speed < ROLL_SPEED_THRESHOLD:
		state.velocity.y = 0.0
		state.spin = Vector3.ZERO
		state.rolling = true
		return StepEvent.ROLLING_STARTED

	var horizontal := Vector3(state.velocity.x, 0.0, state.velocity.z)
	var forward: Vector3 = horizontal.normalized() if horizontal.length() > 0.01 else Vector3.ZERO
	var side: Vector3 = _sidespin_direction(state.velocity)
	# Slow balls carry less spin into the bounce.
	var kick_factor: float = minf(horizontal.length() / SPIN_KICK_FULL_SPEED, 1.0)
	horizontal *= BOUNCE_HORIZONTAL_RETENTION
	horizontal += forward * state.spin.y * SPIN_BOUNCE_FORWARD_KICK * kick_factor
	horizontal += side * state.spin.x * SPIN_BOUNCE_SIDE_KICK * kick_factor

	var restitution: float = lerpf(
		BOUNCE_RESTITUTION_SOFT,
		BOUNCE_RESTITUTION_HARD,
		clampf(impact_speed / BOUNCE_HARD_IMPACT_SPEED, 0.0, 1.0)
	)
	var spin_lift: float = 1.0 + state.spin.y * SPIN_BOUNCE_LIFT
	state.velocity = Vector3(horizontal.x, impact_speed * restitution * spin_lift, horizontal.z)
	state.spin *= SPIN_RETENTION_ON_BOUNCE
	return StepEvent.BOUNCED


func _roll(state: State, delta: float) -> void:
	var speed: float = state.velocity.length()
	if speed > 0.0:
		state.velocity *= maxf(speed - ROLL_DECELERATION * delta, 0.0) / speed
	state.position += state.velocity * delta
	state.position.y = RADIUS


## Handles the ball crossing the net plane during the last step: it either clears the net,
## clips the cord and dribbles over slowed down, or runs into the net and drops back.
func _collide_with_net(state: State, previous_position: Vector3) -> StepEvent:
	if previous_position.z * state.position.z > 0.0 or previous_position.z == 0.0:
		return StepEvent.NONE

	var crossing: float = previous_position.z / (previous_position.z - state.position.z)
	var crossing_point: Vector3 = previous_position.lerp(state.position, crossing)
	var cord: float = net_height(crossing_point.x)
	if crossing_point.y - RADIUS >= cord:
		return StepEvent.NONE

	if crossing_point.y + RADIUS * 0.5 >= cord:
		# Clips the cord: pops up a little and dribbles over.
		state.velocity *= NET_CORD_SPEED_RETENTION
		state.velocity.y = absf(state.velocity.y) * 0.5 + 0.5
		state.spin = Vector3.ZERO
		return StepEvent.CLIPPED_NET_CORD

	# Runs into the net: stays on the hitter's side and drops.
	var hitter_side: float = signf(previous_position.z)
	state.position = Vector3(crossing_point.x, crossing_point.y, hitter_side * (RADIUS + 0.01))
	state.velocity = Vector3(
		state.velocity.x * 0.3, minf(state.velocity.y, 0.0) * 0.3, -state.velocity.z * NET_REBOUND
	)
	state.spin = Vector3.ZERO
	return StepEvent.HIT_NET


## Where and when a ball hit from `start_position` with `start_velocity` first lands,
## ignoring the net (the aim of a shot; the net may still stop it).
func _simulate_landing(
	start_position: Vector3, start_velocity: Vector3, spin_value: Vector3
) -> TrajectoryStep:
	return _simulate_flight(start_position, start_velocity, spin_value)[-1]


## Velocity that makes a ball with the given spin land on `target_position`, passing over the
## net cord with at least `net_clearance` meters to spare: the forward speed starts at
## `velocity_z0` and is lowered (for a higher arc) until the ball clears the net, like a player
## would play a safer, loopier shot.
func calculate_velocity(
	start_position: Vector3,
	target_position: Vector3,
	velocity_z0: float,
	spin_value: Vector3,
	net_clearance: float
) -> Vector3:
	var forward_speed: float = velocity_z0
	var shot_velocity: Vector3 = _solve_velocity(
		start_position, target_position, forward_speed, spin_value
	)
	for _attempt in range(NET_CLEARANCE_MAX_ATTEMPTS):
		if _net_clearance(start_position, shot_velocity, spin_value) >= net_clearance:
			break
		forward_speed *= NET_CLEARANCE_SPEED_FACTOR
		shot_velocity = _solve_velocity(start_position, target_position, forward_speed, spin_value)
	return shot_velocity


## How far above the net cord (m) a ball hit with `start_velocity` passes; INF if it does not
## cross the net before landing, negative if it would hit the net.
func _net_clearance(start_position: Vector3, start_velocity: Vector3, spin_value: Vector3) -> float:
	var previous: Vector3 = start_position
	for trajectory_step in _simulate_flight(start_position, start_velocity, spin_value):
		var point: Vector3 = trajectory_step.point
		if previous.z * point.z <= 0.0 and previous.z != 0.0:
			var crossing: Vector3 = previous.lerp(point, previous.z / (previous.z - point.z))
			return crossing.y - RADIUS - net_height(crossing.x)
		previous = point
	return INF


## Velocity with the given forward speed that lands on `target_position`. The sideways speed is
## corrected by the landing error over the flight time; the vertical speed by the landing depth
## error over the measured depth change per m/s of vertical speed.
func _solve_velocity(
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
		if absf(error_x) < VELOCITY_SOLVER_TOLERANCE and absf(error_z) < VELOCITY_SOLVER_TOLERANCE:
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


## Predicts the ball's trajectory with the same simulation the ball runs (walls excluded) and
## keeps it in `trajectory`. Step bounces count since the last stroke.
func predict_trajectory(
	steps: int = GameConstants.TRAJECTORY_PREDICTION_STEPS,
	time_step: float = GameConstants.TRAJECTORY_TIME_STEP
) -> Array[TrajectoryStep]:
	var state := State.new(global_position, velocity, spin, _rolling)
	trajectory = _simulate(state, steps, time_step, true, bounces_since_stroke, false)
	return trajectory


## Flight of a ball launched from `start_position` until it first lands, ignoring the net.
func _simulate_flight(
	start_position: Vector3, start_velocity: Vector3, spin_value: Vector3
) -> Array[TrajectoryStep]:
	var state := State.new(start_position, start_velocity, spin_value, false)
	var steps: int = ceili(TRAJECTORY_MAX_TIME / TRAJECTORY_SIMULATION_DT)
	return _simulate(state, steps, TRAJECTORY_SIMULATION_DT, false, 0, true)


## Runs the simulation from `state` for up to `steps` steps; stops when the ball comes to rest
## (or at its first bounce if `stop_at_first_bounce`).
func _simulate(
	state: State,
	steps: int,
	time_step: float,
	with_net: bool,
	bounces: int,
	stop_at_first_bounce: bool
) -> Array[TrajectoryStep]:
	var simulated: Array[TrajectoryStep] = []
	var landed_bounces: int = bounces + 1
	for step_index in steps:
		var event: StepEvent = _simulate_step(state, time_step, with_net)
		if event == StepEvent.BOUNCED or event == StepEvent.ROLLING_STARTED:
			bounces += 1
		simulated.append(TrajectoryStep.new(state.position, (step_index + 1) * time_step, bounces))
		if stop_at_first_bounce and bounces >= landed_bounces:
			break
		if state.velocity.length() < GameConstants.TRAJECTORY_STOP_VELOCITY_THRESHOLD:
			break
	return simulated
