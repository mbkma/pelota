class_name Player
extends CharacterBody3D

signal ball_hit
signal just_served
signal target_point_reached
signal ready_to_serve
signal ready_to_receive
signal challenged
signal ball_spawned(ball)
signal input_changed(timing)

@onready var ball_scene := preload("res://src/ball.tscn")
@onready var model: Model = $Model
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

var ai_input = "res://src/players/inputs/ai/ai_input.tscn"
var human_input = "res://src/players/inputs/keyboard_input.tscn"

enum InputType { KEYBOARD, CONTROLLER, AI }
@export var input: InputType
@export var input_node: Node

@export var player_data: PlayerData
@export var stats: Dictionary
@export var camera: Camera3D
@export var ball: Ball
@export var move_speed := 5.0
@export var is_serving := false
@export var team_index: int

@onready var stroke: Stroke = $Strokes

var animation_hit_time := 0.37
var active_stroke: Stroke
var vel := Vector3.ZERO

const DISTANCE_THRESHOLD := 0.01
var path := []
@export var ball_aim_marker: MeshInstance3D


func _ready() -> void:
	stats = player_data.stats
	$Label3D.text = player_data.last_name
	#if input == InputType.AI:
	#$Label3D.text += " (CPU)"
	#input_node = load(ai_input).instantiate()
	#else:
	#input_node = load(human_input).instantiate()
	#add_child(input_node)
	#strokes.setup(self)
	model.racket_forehand.body_entered.connect(_on_RacketArea_body_entered)
	model.racket_backhand.body_entered.connect(_on_RacketArea_body_entered)


func setup(data: PlayerData, ai_controlled: bool) -> void:
	player_data = data

	#var mesh := $"Model/v3player/Rig/Skeleton3D/shirt" as MeshInstance3D
	#var new_mat = mesh.get_active_material(0).duplicate()
	#new_mat.albedo_color = Color(randf(), randf(), randf())
	#mesh.set_surface_override_material(0, new_mat)


func setup_singles_match(sm: SinglesMatch):
	input_node.setup(sm)


func setup_training(training):
	pass


func compute_move_dir() -> Vector3:
	var move_direction := Vector3.ZERO
	if path.size() > 0:
		assert(path.size() == 1)
		move_direction = _move_to_target()

	return move_direction


func _move_to_target() -> Vector3:
	var direction := Vector3.ZERO
	if path.size() > 0:
		if position.distance_squared_to(path[0]) < DISTANCE_THRESHOLD:
			path.remove_at(0)
			emit_signal("target_point_reached")
		else:
			#if sign(path[0].z) != sign(position.z):
			#printerr("I dont move accross the net!")
			#path.remove_at(0)
			#return Vector3.ZERO

			direction = (path[0] - position).normalized()
			direction.y = 0

	return direction


func move_to(target: Vector3) -> void:
	cancel_movement()
	path.append(target)
	#print(player_data.last_name, " path: ", path)


func cancel_movement() -> void:
	path = []


func set_active_stroke(ball_position: Vector3, time: float) -> void:
	if stroke.stroke_type == stroke.StrokeType.SERVE:
		active_stroke = stroke
		return

	active_stroke = stroke
	var t = max(0, time - animation_hit_time)
	if t > 0:
		await get_tree().create_timer(t).timeout

	model.set_stroke(active_stroke, ball_position)
	model.transition_to(model.States.STROKE)


func cancel_stroke() -> void:
	active_stroke = null
	model.transition_to(model.States.MOVE)


var friction := 0.3
var acceleration := 0.1
var move_vel := Vector3.ZERO


func apply_movement(direction: Vector3, delta: float) -> void:
#	uncomment the following for smooth roation in move direction
#	if direction != Vector3.ZERO:
#		model.rotation.y = lerp_angle(model.rotation.y, sign(position.z)*atan2(-direction.x, -direction.z), 15*delta)
#	else:
#		model.rotation.y = lerp_angle(model.rotation.y, 0, 15*delta)

	direction = direction.normalized()
	model.set_move_direction(direction)

	if not is_on_floor():
		vel.y += -GlobalPhysics.GRAVITY * 2 * delta
	else:
		vel.y = -GlobalPhysics.GRAVITY / 10

	vel.x = direction.x * move_speed
	vel.z = direction.z * move_speed

	# If there's input, accelerate to the input vel
	if vel.length() > 0:
		move_vel = move_vel.lerp(vel, acceleration)
	else:
		# If there's no input, slow down to (0, 0)
		move_vel = move_vel.lerp(Vector3.ZERO, friction)

	velocity = move_vel
	move_and_slide()
	move_vel = vel


func apply_racket_input() -> void:
	pass


func prepare_serve() -> void:
	emit_signal("ready_to_serve")


#	root_state_machine.travel("serve-dribble-ball-loop")
#	await get_tree().create_timer(3).timeout
#	root_state_machine.travel("before-serve-loop")


func challenge() -> void:
	emit_signal("challenged")


func serve() -> void:
	if not active_stroke:
		return

	if ball:
		ball.queue_free()

	model.set_stroke(active_stroke)
	model.transition_to(model.States.STROKE)

	ball = ball_scene.instantiate()
	ball.initial_position = position + model.toss_point
	ball.initial_velocity = Vector3(0, 6, 0)
	get_parent().add_child(ball)
	emit_signal("ball_spawned", ball)

	get_tree().call_group("Player", "set_active_ball", ball)
	#await get_tree().create_timer(1).timeout
	#print("serve as", active_stroke)


#
#hit_ball(ball)
#emit_signal("just_served")


func _on_RacketArea_body_entered(body) -> void:
	if body is not Ball or body != ball:  # only do strokes on the active ball
		return

	if active_stroke == null:
		return

	hit_ball(ball)


func hit_ball(ball: Ball) -> void:
	if active_stroke == null:
		return
	active_stroke.execute_stroke(ball)
	emit_signal("ball_hit")
	cancel_stroke()


func player_grunt_sound():
	if active_stroke.stroke_type != stroke.StrokeType.BACKHAND_SLICE:
		var grunts = player_data.sounds.grunt_flat
		if grunts.size() > 0 and randf() < player_data.sounds.grunt_frequency:
			audio_stream_player.stream = grunts[randi() % grunts.size()]
			audio_stream_player.play()


func set_active_ball(b: Ball) -> void:
	ball = b
	print(player_data.last_name, ": New ball!", ball.global_position)
