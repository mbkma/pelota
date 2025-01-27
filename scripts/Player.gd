class_name Player extends CharacterBody3D

# Grabs the prebuilt AnimationTree
@onready var PlayerAnimationTree = $AnimationTree.get_path()
@onready var animation_tree = get_node(PlayerAnimationTree)
@onready var playback = animation_tree.get("parameters/playback")

# Stroke Types
enum StrokeType { NONE, FOREHAND, BACKHAND, SLICE }
var stroke_type: StrokeType = StrokeType.NONE

# Allows to pick your chracter's mesh from the inspector
@export_node_path("Node3D") var PlayerCharacterMesh: NodePath
@onready var player_mesh = get_node(PlayerCharacterMesh)

@export var id = 1

# Gamplay mechanics and Inspector tweakables
@export var gravity = 9.8
@export var jump_force = 9
@export var walk_speed = 1.3
@export var run_speed = 5.5
@export var dash_power = 12  # Controls roll and big attack speed boosts
@export var player_strength: float = 1.0  # 1.0 represents average strength

@export var active_camera: Camera3D

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

# Signals for stroke detection
signal ball_hit
@onready var racket_hitting_area: Area3D = $RacketHittingArea
@onready var id_label: Label3D = $IdLabel


func _ready():  # Camera based Rotation
	direction = Vector3.BACK.rotated(Vector3.UP, $Camroot/h.global_transform.basis.get_euler().y)
	racket_hitting_area.body_entered.connect(_on_ball_entered)
	id_label.text = "Player " + str(id)
	
func _on_ball_entered(body):
	# Ensure the body is the tennis ball and a swing is active
	if body.name == "TennisBall" and is_swing_active():
		emit_signal("ball_hit", body)
		apply_hit_force(body)


func is_swing_active() -> bool:
	# Check if the player is pressing any stroke-related input
	return Input.is_action_pressed("swing")


func apply_hit_force(ball):
	# Determine the force and direction based on input
	var direction = get_stroke_direction()
	var force = 15  # Adjust this value based on the desired ball speed
	ball.apply_impulse(Vector3.ZERO, direction.normalized() * force)


func get_stroke_direction() -> Vector3:
	# Example: Adjust direction based on player input (e.g., forehand/backhand)
	var base_direction = Vector3(1, 0.5, 1)  # Default direction
	#if Input.is_action_pressed("aim_up"):
		#base_direction.y += 0.5
	#elif Input.is_action_pressed("aim_down"):
		#base_direction.y -= 0.5
	#if Input.is_action_pressed("aim_left"):
		#base_direction.x -= 0.5
	#elif Input.is_action_pressed("aim_right"):
		#base_direction.x += 0.5
	return base_direction


func _input(event):  # All major mouse and button input events
	if event is InputEventMouseMotion:
		aim_turn = -event.relative.x * 0.015  # animates player with mouse movement while aiming

	# Stroke type selection based on input
	if Input.is_action_pressed("forehand"):
		stroke_type = StrokeType.FOREHAND
		hit_ball()
		print("forehand")
	elif Input.is_action_pressed("backhand"):
		stroke_type = StrokeType.BACKHAND
		hit_ball()
	elif Input.is_action_pressed("slice"):
		stroke_type = StrokeType.SLICE
		hit_ball()


func handle_animation():
	match stroke_type:
		StrokeType.FOREHAND:
			print(playback.get_current_node())
			if forehand_node_name:
				print("forehand anim")
				playback.travel(forehand_node_name)
			stroke_type = StrokeType.NONE
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
		var cam_transform = active_camera.global_transform
		var forward = -cam_transform.basis.z.normalized()
		var right = -cam_transform.basis.x.normalized()

		direction = Vector3(
			Input.get_action_strength("left") - Input.get_action_strength("right"),
			0,
			Input.get_action_strength("forward") - Input.get_action_strength("backward")
		)
		direction = (forward * direction.z + right * direction.x).normalized()
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

	# Movment mechanics with limitations
	if is_hitting == true:
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
