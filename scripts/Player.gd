class_name Player extends CharacterBody3D

# Movement variables
@export var speed: float = 10.0
@export var jump_speed: float = 15.0
@export var gravity: float = -9.8

# Player state
var is_serving: bool = false
var is_rallying: bool = false

# Input mappings
var move_direction: Vector3 = Vector3.ZERO

@onready var ball: Ball = get_tree().root.get_node("Game/Ball")  # Adjust path if necessary


func _ready():
	# Initialization logic here
	pass


func _physics_process(delta: float):
	handle_movement(delta)
	handle_racket_swing()
	check_ball_interaction()


func handle_movement(delta: float):
	var direction: Vector3 = Vector3.ZERO

	if Input.is_action_pressed("ui_up"):
		direction.z -= 1
	if Input.is_action_pressed("ui_down"):
		direction.z += 1
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_right"):
		direction.x += 1

	direction = direction.normalized()
	move_direction = direction * speed

	# Apply gravity
	velocity.y += gravity * delta

	# Move the character
	move_and_slide()


func handle_racket_swing():
	# Placeholder for racket swing logic, like animation or ball hitting
	if Input.is_action_just_pressed("swing_racket"):
		# Implement racket swing logic here
		pass


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
