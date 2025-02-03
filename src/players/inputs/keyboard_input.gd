class_name HumanInput
extends Node

signal aiming_at_pos(pos)
signal input_changed(time_score)
signal pace_changed(pace)

var sm: SinglesMatch
var player: Player

var move_input_blocked := false
var stroke_input_blocked := true
var input_blocked := false

var mouse_from := Vector2.ZERO
var mouse_to := Vector2.ZERO
var stroke = null
var pred = null

var timing_score := 0.0
var mouse_pressed := false
var aiming_at := Vector3.ZERO
var input_pace := 0.0


func _ready() -> void:
	player = get_parent()
	await get_tree().create_timer(2).timeout
	stroke_input_blocked = false
	player.ball_aim_marker.global_position = _get_default_aim()
	player.ball_aim_marker.visible = true
	player.ball_hit.connect(_on_Player_ball_hit)


func setup(singles_match):
	#player.timing.show()
	sm = singles_match

	#sm.get_opponent(player).ball_hit.connect(_on_Opponent_ball_hit)
	sm.state_changed.connect(_on_SinglesMatch_state_changed)

func _process(delta: float) -> void:
	if player and player.ball:
		var dist = GlobalUtils.get_horizontal_distance(player, player.ball)
		if dist < 0 or player.ball.velocity.length() < 0.1:
			player.cancel_stroke()
			move_input_blocked = false

func _physics_process(delta: float) -> void:
	if input_blocked:
		return

	if move_input_blocked:
		var move_dir = player.compute_move_dir()
		player.apply_movement(move_dir, delta)
	else:
		var input_direction := get_input_direction()

		if Input.is_action_pressed("sprint"):
			player.move_speed = 7
			player.acceleration = 0.2
		else:
			player.acceleration = 0.1
			player.move_speed = 5
		player.apply_movement(input_direction, delta)

	if not stroke_input_blocked:
		get_stroke_input(delta)

		if Input.is_action_just_released("strike"):
			print(input_pace)
			if not player.ball:
				printerr("Player has no ball")
			else:
				stroke = _construct_stroke_from_input(aiming_at, input_pace)
				if stroke:
					set_stroke_input()

	if Input.is_action_just_pressed("challenge"):
		player.challenge()


static func get_input_direction() -> Vector3:
	return Vector3(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		0,
		Input.get_action_strength("move_front") - Input.get_action_strength("move_back")
	)


func get_stroke_input(delta: float):
	if Input.is_action_just_pressed("strike"):
		print("STRIKE PRESSED")
		mouse_from = get_viewport().get_mouse_position()
	if Input.is_action_pressed("strike"):
		input_pace += 0.1
		emit_signal("pace_changed", input_pace)
		mouse_to = get_viewport().get_mouse_position()
		aiming_at = _get_aim_pos(mouse_from, mouse_to)
		player.ball_aim_marker.global_position = aiming_at
		player.ball_aim_marker.visible = true


func set_stroke_input() -> void:
	if player.is_serving:
		player.prepare_serve()
		player.set_active_stroke(stroke, Vector3.ZERO, 0)
		player.serve()
		#clear_stroke_input()

	var p = find_closest_point(player.ball.trajectory, player.model.forehand_up_point.z)
	move_input_blocked = true
	_adjust_position_to_stroke(p)
	player.set_active_stroke(stroke, Vector3.ZERO, 0)

	emit_signal("input_changed", timing_score)
	clear_stroke_input()


func clear_stroke_input():
	pred = null
	input_pace = 0.0
	player.ball_aim_marker.visible = false


func _get_default_aim() -> Vector3:
	var forward := -player.basis.z.normalized()
	var right := player.basis.x.normalized()
	var default_aim := forward * 9
	if player.is_serving:
		default_aim = forward * 5 + sign(player.position.x) * right * -3
	return default_aim


func _get_aim_pos(mouse_from: Vector2, mouse_to: Vector2) -> Vector3:
	var to := Vector3.ZERO

	var default_aim := _get_default_aim()

	to.z = default_aim.z + sign(player.position.z) * (mouse_to - mouse_from).y / 100
	to.x = default_aim.x + sign(player.position.z) * (mouse_to - mouse_from).x / 100

	return to


func _construct_stroke_from_input(aim: Vector3, pace: float):
	var dist = GlobalUtils.get_horizontal_distance(player, player.ball)
	if dist < 10 and dist > 0:
		return {
			"anim_id": player.model.Strokes.FOREHAND,
			"pace": player.stats.forehand_pace + pace,
			"to": aim,
			"spin": player.stats.backhand_spin,
			"height": 1 + player.stats.backhand_spin * 0.1
		}
	return null
	#if player.is_serving:
	#return {
	#"anim_id": player.model.Strokes.SERVE,
	#"pace": player.stats.serve_pace + randf_range(10, 20),
	#"to": aim,
	#"spin": 0,
	#"height": 1.1
	#}

	#if sign(player.position.z) * (pred.pos.x - player.position.x) > 0:
	#return {
	#"anim_id": player.model.Strokes.FOREHAND,
	#"pace": player.stats.forehand_pace + pace,
	#"to": aim,
	#"spin": player.stats.backhand_spin,
	#"height": 1 + player.stats.backhand_spin * 0.1
	#}
	#else:
	#if Input.is_action_pressed("slice"):
	#return {
	#"anim_id": player.model.Strokes.BACKHAND_SLICE,
	#"pace": 20,
	#"to": aim,
	#"spin": -5,
	#"height": 1.3
	#}
	#else:
	#return {
	#"anim_id": player.model.Strokes.BACKHAND,
	#"pace": player.stats.backhand_pace + pace,
	#"to": aim,
	#"spin": player.stats.backhand_spin,
	#"height": 1 + player.stats.backhand_spin * 0.1
	#}


func _on_Player_ball_hit():
	print("Received player ball hit!")
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


func find_closest_point(points: Array, target_z: float) -> Vector3:
	var closest_point: Vector3 = Vector3.ZERO
	var closest_distance: float = INF # Start with a large distance

	for point in points:
		var distance = abs(point.z - target_z)

		# Check if this point is closer than the previous closest point
		if distance < closest_distance:
			closest_distance = distance
			closest_point = point
		else:
			# If the distance is increasing, we can stop searching
			break

	return closest_point


func _adjust_position_to_stroke(p):
	var x_offset = 0
	if stroke.anim_id == player.model.Strokes.FOREHAND:
		x_offset = player.model.forehand_up_point.x
	else:
		x_offset = player.model.backhand_up_point.x
	var final_move_pos = p - x_offset * player.right
	final_move_pos.y = 0
	player.move_to(final_move_pos)
