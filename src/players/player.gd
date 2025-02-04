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
@onready var strokes: Node = $Strokes
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

var ai_input = "res://src/players/inputs/ai_input.tscn"
var human_input = "res://src/players/inputs/keyboard_input.tscn"
enum InputType { KEYBOARD, CONTROLLER, AI }
@export var input: InputType

var input_node: Node

@export var player_data: PlayerData
@export var stats: Dictionary
@export var camera: Camera3D
@export var ball: Ball
@export var move_speed := 5.0
@export var is_serving := false
@export var team_index: int

var animation_hit_time := 0.37
var active_stroke = null
var vel := Vector3.ZERO

const DISTANCE_THRESHOLD := 0.01
var path := []
@onready var ball_aim_marker: MeshInstance3D = $BallAimMarker

var forward := -basis.z.normalized()
var right := basis.x.normalized()


func _ready() -> void:
	stats = player_data.stats
	$Label3D.text = player_data.last_name
	if input == InputType.AI:
		$Label3D.text += " (CPU)"
		input_node = load(ai_input).instantiate()
	else:
		input_node = load(human_input).instantiate()
	add_child(input_node)
	strokes.setup(self)
	model.racket_forehand.body_entered.connect(_on_RacketArea_body_entered)
	model.racket_backhand.body_entered.connect(_on_RacketArea_body_entered)


func setup(data: PlayerData, ai_controlled: bool) -> void:
	player_data = data

	self.ai_controlled = ai_controlled

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
			direction = path[0] - position
			direction.y = 0

	return direction


func move_to(target: Vector3) -> void:
	cancel_movement()
	path.append(target)


func cancel_movement() -> void:
	path = []


func set_active_stroke(stroke: Dictionary, ball_position: Vector3, time: float) -> void:
	if stroke.anim_id == model.Strokes.SERVE:
		active_stroke = stroke
		return

	active_stroke = stroke
	var t = max(0, time - animation_hit_time)
	if t > 0:
		await get_tree().create_timer(t).timeout

	var stroke_name
	if stroke.anim_id == 0:
		stroke_name = "backhand"
	if stroke.anim_id == 2:
		stroke_name = "forehand"
	else:
		stroke_name = "backhand"
	model.set_stroke(stroke_name, ball_position)
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
		vel.y += -GlobalPhysics.DEFAULT_GRAVITY * 2 * delta
	else:
		vel.y = -GlobalPhysics.DEFAULT_GRAVITY / 10

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
	model.set_stroke("serve")
	model.transition_to(model.States.STROKE)
	respawn_ball()


# this function gets called from animation "serve"
func respawn_ball() -> void:
	if not active_stroke:
		return

	print("New Ball!")

	if ball:
		ball.queue_free()

	ball = ball_scene.instantiate()
	ball.initial_position = position + model.toss_point
	ball.initial_velocity = Vector3(0, 6, 0)
	get_parent().add_child(ball)
	emit_signal("ball_spawned", ball)

	get_tree().call_group("Player", "set_active_ball", ball)

	await get_tree().create_timer(1).timeout
	var vel = GlobalPhysics.get_velocity_stroke_from_to(
		ball.position,
		active_stroke.to,
		-sign(position.z) * active_stroke.pace,
		active_stroke.spin,
		active_stroke.height
	)
	hit_ball(ball as Ball, vel, active_stroke.spin)
	emit_signal("just_served")


func _on_RacketArea_body_entered(body) -> void:
	if body is not Ball or body != ball:  # only do strokes on the active ball
		return

	if active_stroke == null:
		return

	_modify_active_stroke()
	var vel = GlobalPhysics.get_velocity_stroke_from_to(
		body.position,
		active_stroke.to,
		-sign(position.z) * active_stroke.pace,
		active_stroke.spin,
		active_stroke.height
	)

	hit_ball(body, vel, active_stroke.spin)


#
#func ready_to_receive() -> void:
##	root_state_machine.travel("receive-loop")
#	emit_signal("ready_to_receive")


func _modify_active_stroke() -> void:
	var rand_factor = (player_data.stats.control + ball.velocity.length() * 3.6) / 100
	active_stroke.to += rand_factor * Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))


func hit_ball(ball: Ball, vel: Vector3, spin: float) -> void:
	ball.apply_stroke(vel, spin)
	_play_stroke_sound()

	emit_signal("ball_hit")
	print("ball_hit. speed: ", vel.length() * 3.6, "km/h vel: ", vel)
	cancel_stroke()
	player_data.set_stat("endurance", player_data.stats.endurance - randf_range(2, 5))


func _play_stroke_sound() -> void:
	if active_stroke.anim_id == model.Strokes.BACKHAND_SLICE:
		strokes.sounds_slice[randi() % strokes.sounds_slice.size()].play()
	else:
		var grunts = player_data.sounds.grunt_flat
		if grunts.size() > 0 and randf() < player_data.sounds.grunt_frequency:
			audio_stream_player.stream = grunts[randi() % grunts.size()]
			audio_stream_player.play()
		else:
			strokes.sounds_flat[randi() % strokes.sounds_flat.size()].play()


func set_active_ball(b: Ball) -> void:
	ball = b
