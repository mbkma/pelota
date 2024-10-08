class_name Ball extends RigidBody3D

@export var start_velocity: Vector3 = Vector3(0, 10, 0)  # Initial velocity for the ball (can be set in the editor)
var spin: Vector3 = Vector3()  # Spin vector (in radians per second)
var drag_coefficient: float = 0.47  # Approximate drag coefficient for a sphere
var air_density: float = 1.225  # kg/m³ at sea level
var ball_radius: float = 0.033  # Radius of a tennis ball in meters
var ball_mass: float = 0.057  # Mass of a tennis ball in kilograms
var magnus_coefficient: float = 0.2  # Arbitrary lift factor due to spin
var restitution: float = 0.75  # Coefficient of restitution (bounciness)
var friction: float = 0.03  # Friction coefficient for spin-ground interaction
var rolling_friction: float = 0.02  # Friction coefficient for rolling on the ground
var is_rolling: bool = false  # State to determine if the ball is rolling

@onready var game: Game = get_tree().root.get_node("Game")  # Adjust if necessary
@onready var net: StaticBody3D = get_tree().root.get_node("Net")  # Adjust if necessary

func _ready():
	# Set the initial velocity of the ball when the scene starts
	linear_velocity = start_velocity

func _integrate_forces(state: PhysicsDirectBodyState3D):
	var dt: float = state.step

	# Apply physics forces
	apply_physics_forces(state)

	# Handle ground bounce or transition to rolling
	if is_on_ground(state):
		if not is_rolling:
			handle_bounce(state)
		else:
			handle_rolling(state)

	# Handle player collision
	handle_player_collision(state)

	# Handle court collision (net, boundaries, etc.)
	handle_court_collision(state)

	# Check if the ball is out of bounds
	if is_out_of_bounds():
		game.check_point(global_transform.origin)

func apply_physics_forces(state: PhysicsDirectBodyState3D):
	var velocity: Vector3 = state.linear_velocity
	var g: Vector3 = Vector3(0, -9.81, 0)  # Gravitational acceleration (m/s²)

	var gravity_force: Vector3 = g * ball_mass
	var area: float = PI * ball_radius * ball_radius
	var drag_force: Vector3 = -0.5 * drag_coefficient * air_density * velocity.length_squared() * area * velocity.normalized()
	var magnus_force: Vector3 = magnus_coefficient * spin.cross(velocity)

	var total_force: Vector3 = gravity_force + drag_force + magnus_force
	state.apply_central_force(total_force)

# Handle ball bouncing when it hits the ground
func handle_bounce(state: PhysicsDirectBodyState3D):
	var velocity: Vector3 = state.linear_velocity

	# Reverse and reduce vertical velocity (bouncing)
	if velocity.y < 0:
		velocity.y = -velocity.y * restitution

	# Apply friction to slow down horizontal velocity
	velocity.x *= (1.0 - friction)
	velocity.z *= (1.0 - friction)

	# Check if ball should start rolling (when vertical speed is very low)
	if abs(velocity.y) < 0.5:
		is_rolling = true

	# Update spin as ball bounces
	var ang_velocity: Vector3 = state.angular_velocity
	ang_velocity.x *= (1.0 - friction)
	ang_velocity.z *= (1.0 - friction)
	state.linear_velocity = velocity
	state.angular_velocity = ang_velocity

# Handle rolling motion after the ball stops bouncing
func handle_rolling(state: PhysicsDirectBodyState3D):
	var velocity: Vector3 = state.linear_velocity
	var ang_velocity: Vector3 = state.angular_velocity

	# Match linear velocity to angular velocity to simulate rolling without slipping
	var target_angular_velocity: Vector3 = velocity / ball_radius if velocity.length() > 0 else Vector3.ZERO
	ang_velocity = ang_velocity.lerp(target_angular_velocity, 0.1)

	# Apply gradual rolling friction
	var rolling_friction_factor = 1.0 - rolling_friction * (get_rolling_speed_factor(velocity.length()))
	velocity.x *= rolling_friction_factor
	velocity.z *= rolling_friction_factor

	# Update state with rolling velocities
	state.linear_velocity = velocity
	state.angular_velocity = ang_velocity

	# Stop rolling when velocity is very small
	if velocity.length() < 0.1:
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		is_rolling = false

# Function to determine how much to reduce speed based on rolling velocity
func get_rolling_speed_factor(speed: float) -> float:
	return clamp(speed / 5.0, 0.0, 1.0)  # Reduce more at higher speeds

# Handle player collisions
func handle_player_collision(state: PhysicsDirectBodyState3D):
	var space_state: PhysicsDirectSpaceState3D = state.get_space_state()

	for i in range(state.get_contact_count()):
		var contact_collider: Object = state.get_contact_collider_object(i)

		if contact_collider is Player:
			var contact_normal: Vector3 = state.get_contact_local_normal(i)
			var velocity: Vector3 = state.linear_velocity
			var reflected_velocity: Vector3 = velocity.bounce(contact_normal) * restitution
			var player_velocity: Vector3 = contact_collider.linear_velocity
			reflected_velocity += player_velocity * 0.5
			spin += contact_normal.cross(velocity.normalized()) * 0.1
			state.linear_velocity = reflected_velocity
			is_rolling = false  # Reset rolling state after hitting a player
			return

# Handle court collision (net, boundaries, etc.)
func handle_court_collision(state: PhysicsDirectBodyState3D):
	var velocity: Vector3 = state.linear_velocity

	for i in range(state.get_contact_count()):
		var contact_collider: Object = state.get_contact_collider_object(i)

		if contact_collider == net:
			state.linear_velocity = Vector3.ZERO
			return
		elif contact_collider is StaticBody3D:
			var contact_normal: Vector3 = state.get_contact_local_normal(i)
			if is_boundary_collision(contact_collider):
				velocity = velocity.bounce(contact_normal) * restitution
				state.linear_velocity = velocity
				return

# Detect if ball is on the ground (based on radius and small tolerance)
func is_on_ground(state: PhysicsDirectBodyState3D) -> bool:
	return global_transform.origin.y <= ball_radius + 0.02

# Detect if ball is out of bounds
func is_out_of_bounds() -> bool:
	return global_transform.origin.y <= 0  # Assuming y = 0 is the ground level

# Detect boundary collision (stub function, adjust based on your court layout)
func is_boundary_collision(collider: Object) -> bool:
	return true  # Placeholder logic
