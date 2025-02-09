class_name Player
extends CharacterBody3D

signal serve_requested

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
@onready var audio_stream_player_3d: AudioStreamPlayer3D = $AudioStreamPlayer3D

var ai_input = "res://src/players/inputs/ai/ai_input.tscn"
var human_input = "res://src/players/inputs/keyboard_input.tscn"

enum InputType { KEYBOARD, CONTROLLER, AI }
@export var input: InputType
@export var input_node: InputMethod
@export var player_data: PlayerData
@export var stats: Dictionary
@export var camera: Camera3D
@export var ball: Ball
@export var move_speed := 5.0
@export var is_serving := false
@export var team_index: int
@export var ball_aim_marker: MeshInstance3D

## Sounds related
@export var stroke_sounds_flat := [
	preload("res://assets/sounds/flat_stroke1.wav"),
	preload("res://assets/sounds/flat_stroke2.wav"),
	preload("res://assets/sounds/flat_stroke3.wav"),
]
@export var stroke_sounds_slice := [
	preload("res://assets/sounds/slice_stroke1.wav"),
	preload("res://assets/sounds/slice_stroke2.wav"),
	preload("res://assets/sounds/slice_stroke3.wav"),
]

## Stroke related
var queued_stroke: Stroke

## Move related
var move_velocity := Vector3.ZERO
var real_velocity := Vector3.ZERO
var friction := 1
var acceleration := 0.1
const DISTANCE_THRESHOLD := 0.01
var path := []


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

	serve_requested.connect(input_node.serve_requested)


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


## Move Related
###############


func apply_movement(direction: Vector3, delta: float) -> void:
#	uncomment the following for smooth roation in move direction
#	if direction != Vector3.ZERO:
#		model.rotation.y = lerp_angle(model.rotation.y, sign(position.z)*atan2(-direction.x, -direction.z), 15*delta)
#	else:
#		model.rotation.y = lerp_angle(model.rotation.y, 0, 15*delta)

	direction = direction.normalized()
	model.set_move_direction(direction)

	if not is_on_floor():
		move_velocity.y += -GlobalPhysics.GRAVITY * 2 * delta
	else:
		move_velocity.y = -GlobalPhysics.GRAVITY / 10

	move_velocity.x = direction.x * move_speed
	move_velocity.z = direction.z * move_speed

	# If there's input, accelerate to the input move_velocity
	if direction.length() > 0:
		real_velocity = real_velocity.lerp(move_velocity, acceleration)
	else:
		# If there's no input, slow down to (0, 0)
		real_velocity = real_velocity.lerp(Vector3.ZERO, friction)

	velocity = real_velocity
	move_and_slide()
	#real_velocity = move_velocity


func compute_move_dir() -> Vector3:
	var move_direction := Vector3.ZERO
	if path.size() > 0:
		assert(path.size() == 1)
		move_direction = _get_move_direction()

	return move_direction


func _get_move_direction() -> Vector3:
	var direction := Vector3.ZERO
	if path.size() > 0:
		if position.distance_squared_to(path[0]) < DISTANCE_THRESHOLD:
			path.remove_at(0)
			target_point_reached.emit()
			print(self, ": target point reached ", position)
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


## Stroke related
#################


# Here you can queue all strokes, except serves
func queue_stroke(stroke: Stroke, ball_position: Vector3) -> void:
	if not ball:
		printerr("Player ", self, " has not ball!")

	queued_stroke = stroke
	model.play_stroke_animation(stroke, ball_position)


func _on_RacketArea_body_entered(body) -> void:
	if not body is Ball or not queued_stroke:
		return

	_hit_ball(ball, queued_stroke)
	queued_stroke = null


func _hit_ball(ball: Ball, stroke: Stroke) -> void:
	var stroke_velocity := GlobalPhysics.calculate_velocity(
		ball.position,
		stroke.stroke_target,
		-sign(position.z) * stroke.stroke_power,
		stroke.stroke_spin
	)
	print(stroke.stroke_target)

	ball.apply_stroke(stroke_velocity, stroke.stroke_spin)
	play_stroke_sound(stroke)
	emit_signal("ball_hit")
	cancel_stroke()


func _play_stroke_sound():
	pass


func cancel_stroke() -> void:
	queued_stroke = null
	model.transition_to(model.States.MOVE)


func serve(stroke: Stroke) -> void:
	if ball:
		ball.queue_free()

	model.set_stroke(stroke)
	model.transition_to(model.States.STROKE)

	ball = ball_scene.instantiate()
	ball.initial_position = position + model.toss_point
	ball.initial_velocity = Vector3(0, 6, 0)
	get_parent().add_child(ball)
	emit_signal("ball_spawned", ball)

	get_tree().call_group("Player", "set_active_ball", ball)
	await get_tree().create_timer(1).timeout
	#print("serve as", queued_stroke)

	_hit_ball(ball, stroke)
	just_served.emit()


## Other functions
##################


func prepare_serve() -> void:
	ready_to_serve.emit()


#	root_state_machine.travel("serve-dribble-ball-loop")
#	await get_tree().create_timer(3).timeout
#	root_state_machine.travel("before-serve-loop")


func challenge() -> void:
	emit_signal("challenged")


func _get_grunt_sound() -> AudioStream:
	var stream: AudioStream
	var grunts = player_data.sounds.grunt_flat
	if grunts.size() > 0:
		stream = grunts[randi() % grunts.size()]
	return stream


func play_stroke_sound(stroke: Stroke):
	var stream: AudioStream

	if randf() < player_data.sounds.grunt_frequency:
		stream = _get_grunt_sound()
	else:
		if stroke.stroke_type == stroke.StrokeType.BACKHAND_SLICE:
			stream = stroke_sounds_slice[randi() % stroke_sounds_slice.size()]
		else:
			stream = stroke_sounds_flat[randi() % stroke_sounds_flat.size()]

	audio_stream_player.stream = stream
	audio_stream_player.play()


func set_active_ball(b: Ball) -> void:
	ball = b
	print(player_data.last_name, ": New ball!", ball.global_position)
