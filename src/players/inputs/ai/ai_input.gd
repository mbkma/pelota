# FIXME: this class depends checked SinglesMatch class, which it shouldnt
class_name AiInput
extends InputMethod

var sm: SinglesMatch
var tactics = {
	"DefaultTactics": "res://src/players/inputs/ai/tactics/default.gd",
	"ServeAndVolley": "res://src/players/inputs/ai/tactics/serve_and_volley.gd"
}

var current_tactic = preload("res://src/players/inputs/ai/tactics/default.gd").new():
	set = set_current_tactic
var pivot_point := Vector3.ZERO


func _ready() -> void:
	player = get_parent()
	current_tactic.setup(player)

	pivot_point = Vector3(0, 0, sign(player.position.z) * 13)
	player.ball_hit.connect(on_Player_ball_hit)
	player.target_point_reached.connect(on_player_target_point_reached)
	#player.just_served.connect(on_Player_just_served)
	#player.move_to(Vector3(0,0,-13))
	#await player.target_point_reached
	if player.is_serving:
		make_serve()


func _process(delta: float) -> void:
	if player and player.ball:
		if GlobalUtils.is_flying_towards(player, player.ball):
			if not player.active_stroke:
				do_stroke()
		var dist = GlobalUtils.get_horizontal_distance(player, player.ball)
		if dist < 0 or player.ball.velocity.length() < 0.1:
			player.cancel_stroke()


func do_stroke():
	player.ball.trajectory = player.ball.predict_trajectory()
	var closest_ball_position := GlobalUtils.get_closest_ball_position(player)
	current_tactic.compute_next_stroke(closest_ball_position)
	player.set_active_stroke(closest_ball_position, 0)
	GlobalUtils.adjust_player_to_position(player, closest_ball_position, player.active_stroke)  # FIXME


func setup(_sm: Object) -> void:
	# only for singles match
	sm = _sm
	sm.state_changed.connect(on_SinglesMatch_state_changed)
	sm.get_opponent(player).just_served.connect(on_Opponent_just_served)
	sm.get_opponent(player).ball_hit.connect(on_Opponent_ball_hit)
	sm.get_opponent(player).ready_to_serve.connect(on_Opponent_ready_to_serve)
	move_to_serve_receive()


func set_current_tactic(tactic):
	current_tactic = tactic


func on_Opponent_just_served():
	pass


func _physics_process(delta: float) -> void:
	var move_dir = player.compute_move_dir()
	player.apply_movement(move_dir, delta)


func on_player_target_point_reached():
	return


func on_Player_ball_hit():
	current_tactic.on_Player_ball_hit()


func on_Opponent_ready_to_serve():
	pass


#	player.ready_to_receive()


func move_to_serve_receive():
	var score = sm.match_data.match_score._score
	if player.is_serving:
		var pos = sm.world.get_stadium_position("serve_deuce0")
		if not sm.match_data.match_score.is_points_diff_even():
			pos = sm.world.get_stadium_position("serve_ad0")
		player.move_to(pos)
	else:
		var pos = sm.world.get_stadium_position("receive_deuce1")
		if not sm.match_data.match_score.is_points_diff_even():
			pos = sm.world.get_stadium_position("receive_ad1")
		player.move_to(pos)


func on_SinglesMatch_state_changed(old_state, new_state):
	if (
		new_state == GlobalUtils.MatchStates.IDLE
		or new_state == GlobalUtils.MatchStates.SECOND_SERVE
	):
		# cancel all player movement orders
		player.cancel_movement()
		player.cancel_stroke()
		await get_tree().create_timer(3).timeout
		move_to_serve_receive()
		await player.target_point_reached
		if player.is_serving:
			make_serve()

	pivot_point = Vector3(0, 0, sign(player.position.z) * 13)
	if new_state == GlobalUtils.MatchStates.FAULT:
		player.cancel_movement()
		player.cancel_stroke()


var pred


func on_Opponent_ball_hit():
	pass
	#if not player.ball:
	#return


#
## first, compute next stroke
##	var p1 = GlobalPhysics._get_ball_position_at_ground(player.ball).pos
##	if sm.world.court.get_field_at_pos(p1) == GlobalUtils.OUT:
##		player.cancel_stroke()
##		return
#
#pred = GlobalPhysics.get_ball_position_at(player.ball, player.position.z)
#var ball_pos_prediction = pred.pos
#
##print("BALL PREDICTION", ball_pos_prediction.y)
#
## second, compute how to move in order to do the stroke
#
## if ball outside of comfort zone
#if (
#ball_pos_prediction.y < player.model.forehand_down_point.y
#or ball_pos_prediction.y > player.model.forehand_up_point.y
#):
#pred = GlobalPhysics.get_ball_position_at_height_after_bounce(player.ball, 1)
#
#if not pred:
#return
#
#var stroke = current_tactic.compute_next_stroke(pred)
#var x_offset = 0
#if stroke.anim_id == player.model.Strokes.FOREHAND:
#x_offset = player.model.forehand_up_point.x
#else:
#x_offset = player.model.backhand_up_point.x
#var final_move_pos = pred.pos - x_offset * player.transform.basis.x
#final_move_pos.y = 0
#player.move_to(final_move_pos)
#player.set_active_stroke(stroke, pred.pos, pred.time)


func make_serve():
	player.prepare_serve()
	current_tactic.compute_serve()
	player.set_active_stroke(Vector3.ZERO, 0)
	await get_tree().create_timer(5).timeout
	player.serve()
