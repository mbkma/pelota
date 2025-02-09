class_name HumanInput
extends InputMethod

signal aiming_at_pos(pos)
signal input_changed(time_score)
signal pace_changed(pace)

@export var ball_aim_marker: MeshInstance3D
@export var mouse_sensitivity := 100.0

var sm: SinglesMatch

## Move related
var move_input_blocked := false
var stroke_input_blocked := true
var input_blocked := false

# Stroke Related
var mouse_from := Vector2.ZERO
var mouse_to := Vector2.ZERO
var mouse_pressed := false
var aiming_at := Vector3.ZERO
var input_pace := 0.0



func _ready() -> void:
	player = get_parent()
	await get_tree().create_timer(0.5).timeout
	stroke_input_blocked = false
	ball_aim_marker.position = _get_default_aim()
	ball_aim_marker.visible = true
	player.ball_hit.connect(_on_Player_ball_hit)
	#move_input_blocked = true
	#player.move_to(Vector3(0,0,10))


func _process(delta: float) -> void:
	if player and player.ball:
		var dist = GlobalUtils.get_horizontal_distance(player, player.ball)
		if dist < 0 or player.ball.velocity.length() < 0.1:
			player.cancel_stroke()
			move_input_blocked = false

	if Input.is_action_pressed("sprint"):
		player.move_speed = 7
		player.acceleration = 0.2
	else:
		player.acceleration = 0.1
		player.move_speed = 5




	if not stroke_input_blocked:
		if Input.is_action_just_pressed("strike"):
			input_pace = 0
			mouse_from = get_viewport().get_mouse_position()
		if Input.is_action_pressed("strike"):
			input_pace += 0.1
			emit_signal("pace_changed", input_pace)
			mouse_to = get_viewport().get_mouse_position()
			aiming_at = _get_aim_pos(mouse_from, mouse_to)
			ball_aim_marker.position = aiming_at
			ball_aim_marker.visible = true
		if Input.is_action_just_released("strike"):
			if player.is_serving:
				do_serve(aiming_at, input_pace)
			else:
				if not player.ball:
					printerr("Player has no ball")
				else:
					do_stroke(aiming_at, input_pace)

	if Input.is_action_just_pressed("challenge"):
		player.challenge()



func _physics_process(delta: float) -> void:
	if input_blocked:
		return

	if move_input_blocked:
		var move_dir = player.compute_move_dir()
		player.apply_movement(move_dir, delta)
	else:
		var move_direction := get_move_direction()


		player.apply_movement(move_direction, delta)


## Move related
###############


func get_move_direction() -> Vector3:
	var input := Vector3(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		0,
		Input.get_action_strength("move_front") - Input.get_action_strength("move_back")
	)
	var cam_basis = player.camera.global_basis
	var forward = -cam_basis.z.normalized()
	var right = cam_basis.x.normalized()

	var direction = (forward * input.z + right * input.x).normalized()
	return direction


## Stroke related
#################

func _get_default_aim() -> Vector3:
	var default_aim := Vector3(0, 0, -sign(player.position.z) * 9)
	if player.is_serving:
		default_aim = Vector3(-sign(player.position.x) * 3, 0, -sign(player.position.z) * 3)
	return default_aim


func _get_aim_pos(mouse_from: Vector2, mouse_to: Vector2) -> Vector3:
	var to := Vector3.ZERO

	var default_aim := _get_default_aim()

	to.z = default_aim.z + sign(player.position.z) * (mouse_to - mouse_from).y / mouse_sensitivity
	to.x = default_aim.x + sign(player.position.z) * (mouse_to - mouse_from).x / mouse_sensitivity

	return to


func do_serve(aiming_at, input_pace):
	var stroke = Stroke.new()
	stroke.stroke_type = stroke.StrokeType.SERVE
	stroke.stroke_power = player.stats.serve_pace + input_pace
	stroke.stroke_spin = 0
	stroke.stroke_target = aiming_at

	#player.prepare_serve()
	player.serve(stroke)


func do_stroke(aiming_at, input_pace):
	var closest_ball_position := GlobalUtils.get_closest_ball_position(player)
	print(player.player_data, ": closest_ball_position ", closest_ball_position)

	var stroke := _construct_stroke_from_input(closest_ball_position, aiming_at, input_pace)
	move_input_blocked = true

	player.queue_stroke(stroke, closest_ball_position)
	GlobalUtils.adjust_player_to_position(player, closest_ball_position, stroke)  # FIXME

	clear_stroke_input()


func clear_stroke_input():
	input_pace = 0.0
	ball_aim_marker.visible = false




func _construct_stroke_from_input(closest_ball_position, aim: Vector3, pace: float) -> Stroke:
	var stroke = Stroke.new()
	var to_ball_vector: Vector3 = closest_ball_position - player.position
	var dot_product: float = to_ball_vector.dot(player.basis.x)
	if dot_product > 0:
		stroke.stroke_type = stroke.StrokeType.FOREHAND
		stroke.stroke_power = player.stats.forehand_pace + pace
		stroke.stroke_spin = player.stats.forehand_spin
		stroke.stroke_target = aim
	else:
		if Input.is_action_pressed("slice"):
			stroke.stroke_type = stroke.StrokeType.BACKHAND_SLICE
			stroke.stroke_power = 20
			stroke.stroke_spin = -5
			stroke.stroke_target = aim
		else:
			stroke.stroke_type = stroke.StrokeType.BACKHAND
			stroke.stroke_power = player.stats.backhand_pace + pace
			stroke.stroke_spin = player.stats.backhand_spin
			stroke.stroke_target = aim

	return stroke


## Misc
#######


func setup(singles_match):
	#player.timing.show()
	sm = singles_match

	#sm.get_opponent(player).ball_hit.connect(_on_Opponent_ball_hit)
	sm.state_changed.connect(_on_SinglesMatch_state_changed)

func _on_Player_ball_hit():
	move_input_blocked = false


func _on_SinglesMatch_state_changed(old_state, new_state):
	if new_state == GlobalUtils.MatchStates.FAULT:
		stroke_input_blocked = true
		move_input_blocked = true
		clear_stroke_input()
		await get_tree().create_timer(1).timeout
		stroke_input_blocked = false
	if (
		new_state == GlobalUtils.MatchStates.IDLE
		or new_state == GlobalUtils.MatchStates.SECOND_SERVE
	):
		move_input_blocked = false

#func _on_Opponent_ball_hit():
#if not player.ball:
#return
#
#pred = GlobalPhysics.get_ball_position_at(player.ball, player.position.z)
#var ball_pos_prediction = pred.pos
#
## if ball outside of comfort zone
#if (
#ball_pos_prediction.y < player.model.forehand_down_point.y
#or ball_pos_prediction.y > player.model.forehand_up_point.y
#):
## predict where ball is in comfort zone
#pred = GlobalPhysics.get_ball_position_at_height_after_bounce(player.ball, 1)
