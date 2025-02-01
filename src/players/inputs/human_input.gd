class_name HumanInput
extends Node

signal aiming_at_pos(pos)
signal input_changed(time_score)
signal pace_changed(pace)
@onready var ball_aim_human: MeshInstance3D = $BallAimHuman

var sm: SinglesMatch
var player: BasePlayer

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
	await get_tree().create_timer(2).timeout
	stroke_input_blocked = false

func setup(singles_match):
	player = get_parent()
	#player.timing.show()
	sm = singles_match

	sm.get_opponent(player).ball_hit.connect(_on_Opponent_ball_hit)
	sm.state_changed.connect(_on_SinglesMatch_state_changed)
	player.ball_hit.connect(_on_Player_ball_hit)


func _physics_process(delta: float) -> void:
	if input_blocked:
		return

	if move_input_blocked:
		var move_dir = player.compute_move_dir()
		player.apply_movement(move_dir, delta)
	else:
		var input_direction := get_input_direction()
		if Input.is_action_pressed("shift"):
			player.move_speed = 7
			player.acceleration = 0.2
		else:
			player.acceleration = 0.1
			player.move_speed = 5
		player.apply_movement(sign(player.position.z) * input_direction, delta)

	if not stroke_input_blocked:
		get_stroke_input(delta)

		if Input.is_action_just_released("strike"):
			print(input_pace)
			stroke = _construct_stroke_from_input(aiming_at, input_pace)
			set_stroke_input()

	if Input.is_action_just_pressed("challenge"):
		player.challenge()


static func get_input_direction() -> Vector3:
	return Vector3(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			0,
			Input.get_action_strength("move_back") - Input.get_action_strength("move_front")
		)


func get_stroke_input(delta: float):
	if Input.is_action_just_pressed("strike"):
		mouse_from = get_viewport().get_mouse_position()
	if Input.is_action_pressed("strike"):
		input_pace += 0.1
		emit_signal("pace_changed", input_pace)
		mouse_to = get_viewport().get_mouse_position()
		aiming_at = _get_aim_pos(mouse_from, mouse_to)
		ball_aim_human.position = aiming_at
		ball_aim_human.visible = true


func set_stroke_input() -> void:
	if player.is_serving and (sm.state == GlobalUtils.MatchStates.IDLE or sm.state == GlobalUtils.MatchStates.SERVE or sm.state == GlobalUtils.MatchStates.SECOND_SERVE):
		player.prepare_serve()
		player.set_active_stroke(stroke, Vector3.ZERO, 0)
		player.serve()
		clear_stroke_input()

	if not pred:
		return

	timing_score = -sign(player.position.z) * (player.ball.position.z - player.position.z)
	move_input_blocked = true
	_adjust_position_to_stroke(pred.pos)
	player.set_active_stroke(stroke, pred.pos, 0)

	_show_stroke_feedback()
	emit_signal("input_changed", timing_score)
	clear_stroke_input()


func _show_stroke_feedback():
	if timing_score > 0.0:
		if timing_score < 1:
			player.timing.text = "A Bit to Late! (Score: " + str(timing_score) + ")"
			player.timing.modulate = Color(0.5, 0, 0)
		elif timing_score > 2:
			player.timing.text = "Too Early! (Score: " + str(timing_score) + ")"
			player.timing.modulate = Color(0, 0, 0.5)
		else: # > 1 and < 2
			player.timing.text = "Perfect! (Score: " + str(timing_score) + ")"
			player.timing.modulate = Color(0, 1, 0)
	else: # timing_score < 0.0
		player.timing.text = "To Late! (Score: " + str(timing_score) + ")"
		player.timing.modulate = Color(1, 0, 0)


func clear_stroke_input():
	pred = null
	input_pace = 0.0
	ball_aim_human.visible = false


func _get_aim_pos(mouse_from: Vector2, mouse_to: Vector2) -> Vector3:
	var to := Vector3.ZERO
	var default_aim := Vector3(0, 0, -sign(player.position.z) * 9)
	if player.is_serving and (sm.state == GlobalUtils.MatchStates.IDLE or sm.state == GlobalUtils.MatchStates.SECOND_SERVE):
		default_aim = Vector3(-sign(player.position.x) * 3, 0, -sign(player.position.z) * 5)

	to.z = default_aim.z + sign(player.position.z) * (mouse_to - mouse_from).y / 100
	to.x = default_aim.x + sign(player.position.z) * (mouse_to - mouse_from).x / 100

	return to


func _construct_stroke_from_input(aim: Vector3, pace: float) -> Dictionary:
	if player.is_serving and (sm.state == GlobalUtils.MatchStates.IDLE or sm.state == GlobalUtils.MatchStates.SECOND_SERVE):
		return {"anim_id": player.skin.Strokes.SERVE, "pace": player.stats.serve_pace + randf_range(10, 20), "to": aim, "spin": 0, "height": 1.1}

	assert(pred != null)
	if sign(player.position.z) * (pred.pos.x - player.position.x) > 0:
		return {"anim_id": player.skin.Strokes.FOREHAND, "pace": player.stats.forehand_pace + pace, "to": aim, "spin": player.stats.backhand_spin, "height": 1 + player.stats.backhand_spin * 0.1}
	else:
		if Input.is_action_pressed("slice"):
			return {"anim_id": player.skin.Strokes.BACKHAND_SLICE, "pace": 20, "to": aim, "spin": - 5, "height": 1.3}
		else:
			return {"anim_id": player.skin.Strokes.BACKHAND, "pace": player.stats.backhand_pace + pace, "to": aim, "spin": player.stats.backhand_spin, "height": 1 + player.stats.backhand_spin * 0.1}


func _on_Player_ball_hit():
	move_input_blocked = false


func _on_SinglesMatch_state_changed(old_state, new_state):
	if new_state == GlobalUtils.MatchStates.FAULT:
		stroke_input_blocked = true
		move_input_blocked = true
		clear_stroke_input()
		await get_tree().create_timer(1).timeout
		stroke_input_blocked = false
	if new_state == GlobalUtils.MatchStates.IDLE or new_state == GlobalUtils.MatchStates.SECOND_SERVE:
		move_input_blocked = false


func _on_Opponent_ball_hit():
	if not player.ball:
		return

	pred = GlobalPhysics.get_ball_position_at(player.ball, player.position.z)
	var ball_pos_prediction = pred.pos

	# if ball outside of comfort zone
	if ball_pos_prediction.y < player.skin.forehand_down_point.y or ball_pos_prediction.y > player.skin.forehand_up_point.y:
		# predict where ball is in comfort zone
		pred = GlobalPhysics.get_ball_position_at_height_after_bounce(player.ball, 1)


func _adjust_position_to_stroke(ball_pos):
	var x_offset = 0
	if stroke.anim_id == player.skin.Strokes.FOREHAND:
		x_offset = player.skin.forehand_up_point.x
	else:
		x_offset = player.skin.backhand_up_point.x
	var final_move_pos = ball_pos - x_offset * player.transform.basis.x
	final_move_pos.y = 0
	player.move_to(final_move_pos)
