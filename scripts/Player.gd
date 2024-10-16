class_name Player extends CharacterBody3D

# Grabs the prebuilt AnimationTree
@onready var PlayerAnimationTree = $AnimationTree.get_path()
@onready var animation_tree = get_node(PlayerAnimationTree)
@onready var playback = animation_tree.get("parameters/playback")


# Stroke Types
enum StrokeType { FOREHAND, BACKHAND, SLICE }
var stroke_type: StrokeType = StrokeType.FOREHAND


# Allows to pick your chracter's mesh from the inspector
@export_node_path("Node3D") var PlayerCharacterMesh: NodePath
@onready var player_mesh = get_node(PlayerCharacterMesh)

# Gamplay mechanics and Inspector tweakables
@export var gravity = 9.8
@export var jump_force = 9
@export var walk_speed = 1.3
@export var run_speed = 5.5
@export var dash_power = 12  # Controls roll and big attack speed boosts
@export var player_strength: float = 1.0  # 1.0 represents average strength

var is_serving: bool = false
var is_rallying: bool = false

# Input mappings
@onready var ball: Ball = get_tree().root.get_node("Game/Ball")  # Adjust path if necessary

# Animation node names
var idle_node_name = "Idle"
var walk_node_name = "Walk"
var run_node_name = "Run"
var jump_node_name = "Jump"
var forehand_node_name = "Forehand"
var backhand_node_name = "Backhand"


# Condition States
var is_hitting = bool()
var is_walking = bool()
var is_running = bool()

# Physics values
var direction = Vector3()
var horizontal_velocity = Vector3()
var aim_turn = float()
var movement = Vector3()
var vertical_velocity = Vector3()
var movement_speed = int()
var angular_acceleration = int()
var acceleration = int()


func _ready():  # Camera based Rotation
	direction = Vector3.BACK.rotated(Vector3.UP, $Camroot/h.global_transform.basis.get_euler().y)


func _input(event):  # All major mouse and button input events
	if event is InputEventMouseMotion:
		aim_turn = -event.relative.x * 0.015  # animates player with mouse movement while aiming

	# Stroke type selection based on input
	if Input.is_action_pressed("forehand"):
		stroke_type = StrokeType.FOREHAND
		hit_ball()
	elif Input.is_action_pressed("backhand"):
		stroke_type = StrokeType.BACKHAND
		hit_ball()
	elif Input.is_action_pressed("slice"):
		stroke_type = StrokeType.SLICE
		hit_ball()


func handle_animation():
	match stroke_type:
		StrokeType.FOREHAND:
			if forehand_node_name in playback.get_current_node():
				playback.travel(forehand_node_name)	
		StrokeType.BACKHAND:
			pass
		StrokeType.SLICE:
			pass


func _physics_process(delta):
	handle_movement(delta)
	handle_animation()
	#handle_racket_swing()
	#check_ball_interaction()


func check_ball_interaction():
	if ball and is_rallying:
		# Adjust distance as needed
		if global_transform.origin.distance_to(ball.global_transform.origin) < 2.0:
			# Logic for hitting the ball or interacting with it
			pass


func serve_ball():
	if is_serving:
		# Implement logic for serving the ball
		pass


func start_rally():
	is_rallying = true


func end_rally():
	is_rallying = false

### Stroke Logic
# General method to hit the ball
func hit_ball():
	var stroke_power: float = 10.0 * player_strength  # Base power, scaled by player strength
	var stroke_direction: Vector3 = get_stroke_direction()
	
	match stroke_type:
		StrokeType.FOREHAND:
			hit_forehand(stroke_direction, stroke_power)
		StrokeType.BACKHAND:
			hit_backhand(stroke_direction, stroke_power)
		StrokeType.SLICE:
			hit_slice(stroke_direction, stroke_power)

# Helper function to get the direction of the stroke based on player input
func get_stroke_direction() -> Vector3:
	return (ball.global_transform.origin - global_transform.origin).normalized()

# Forehand stroke logic
func hit_forehand(direction: Vector3, power: float):
	var forehand_spin = Vector3(0, 0, power * 0.2)  # Add topspin to the forehand
	ball.linear_velocity = direction * power
	ball.spin = forehand_spin


# Backhand stroke logic
func hit_backhand(direction: Vector3, power: float):
	var backhand_spin = Vector3(0, 0, power * 0.15)  # Less spin on backhand
	ball.linear_velocity = direction * power * 0.9  # Backhand might be slightly weaker
	ball.spin = backhand_spin

# Slice stroke logic
func hit_slice(direction: Vector3, power: float):
	var slice_spin = Vector3(0, -power * 0.3, 0)  # Add underspin to the slice
	ball.linear_velocity = direction * power * 0.7  # Slice is slower and has underspin
	ball.spin = slice_spin


func handle_movement(delta):
	var on_floor = is_on_floor()  # State control for is jumping/falling/landing
	var h_rot = $Camroot/h.global_transform.basis.get_euler().y

	movement_speed = 0
	angular_acceleration = 10
	acceleration = 15

	# Gravity mechanics and prevent slope-sliding
	if not is_on_floor():
		vertical_velocity += Vector3.DOWN * gravity * 2 * delta
	else:
		#vertical_velocity = -get_floor_normal() * gravity / 3
		vertical_velocity = Vector3.DOWN * gravity / 10

	# Defining attack state: Add more attacks animations here as you add more!
	if (
		(forehand_node_name in playback.get_current_node())
		or (backhand_node_name in playback.get_current_node())
	):
		is_hitting = true
	else:
		is_hitting = false

	# Movement input, state and mechanics. *Note: movement stops if hitting
	if (
		Input.is_action_pressed("forward")
		|| Input.is_action_pressed("backward")
		|| Input.is_action_pressed("left")
		|| Input.is_action_pressed("right")
	):
		direction = Vector3(
			Input.get_action_strength("left") - Input.get_action_strength("right"),
			0,
			Input.get_action_strength("forward") - Input.get_action_strength("backward")
		)
		direction = direction.rotated(Vector3.UP, h_rot).normalized()
		is_walking = true

		movement_speed = walk_speed
		is_running = false
	else:
		is_walking = false
		is_running = false

	player_mesh.rotation.y = lerp_angle(
		player_mesh.rotation.y,
		atan2(direction.x, direction.z) - rotation.y,
		delta * angular_acceleration
	)

	# Movment mechanics with limitations during rolls/attacks
	if (is_hitting == true):
		horizontal_velocity = horizontal_velocity.lerp(
			direction.normalized() * .01, acceleration * delta
		)
	else:  # Movement mechanics without limitations
		horizontal_velocity = horizontal_velocity.lerp(
			direction.normalized() * movement_speed, acceleration * delta
		)

	# The Physics Sauce. Movement, gravity and velocity in a perfect dance.
	velocity.z = horizontal_velocity.z + vertical_velocity.z
	velocity.x = horizontal_velocity.x + vertical_velocity.x
	velocity.y = vertical_velocity.y

	move_and_slide()

	# ========= State machine controls =========
	# The booleans of the on_floor, is_walking etc, trigger the
	# advanced conditions of the AnimationTree, controlling animation paths

	# on_floor manages jumps and falls
	animation_tree["parameters/conditions/IsOnFloor"] = on_floor
	animation_tree["parameters/conditions/IsInAir"] = !on_floor
	# Moving and running respectively
	animation_tree["parameters/conditions/IsWalking"] = is_walking
	animation_tree["parameters/conditions/IsNotWalking"] = !is_walking
	animation_tree["parameters/conditions/IsRunning"] = is_running
	animation_tree["parameters/conditions/IsNotRunning"] = !is_running
	# Attacks and roll don't use these boolean conditions, instead
	# they use "travel" or "start" to one-shot their animations.
