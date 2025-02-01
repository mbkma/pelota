class_name SinglesMatch
extends Node

signal state_changed(old_state, new_state)
signal level_changed(level_name, init_data)

var world
var court: Court
var television: Television

var _active_ball: Ball = null

# sides / directions
var players: Array

var team1_side := GlobalUtils.SIDE1
var team2_side := GlobalUtils.SIDE0
var active_player_index := 0
var serve_direction := GlobalUtils.SIDE0
var valid_side = serve_direction

var ground_contacts := 0
var ball_in_play := false

var match_data: MatchData

var state = GlobalUtils.MatchStates.IDLE
var fault_reason: String


func init_scene(init_data: Dictionary):
	world = init_data.world.instantiate()
	add_child(world)

	court = world.court
	television = world.television

	match_data = init_data.match_data as MatchData
	players.append(GlobalGameData.create_player(
		match_data.player0,
		false)
		)
	players.append(GlobalGameData.create_player(
		match_data.player1,
		true)
		)

	active_player_index = 0
	players[0].team_index = 0
	players[1].team_index = 1
	players[0].is_serving = true
	players[0].camera = television.player_cameras[0]
	players[1].camera = television.player_cameras[1]
	players[0].position = world.get_stadium_position("serve_deuce0")
	players[1].position = world.get_stadium_position("receive_deuce1")
	players[1].rotate_y(PI)

	for player in players:
		add_child(player)
		player.setup_singles_match(self)
		player.ball_spawned.connect(on_Player_ball_spawned)
		player.ready_to_serve.connect(on_Player_ready_to_serve)
		player.ball_hit.connect(on_Player_ball_hit)

	world.setup_singles_match(self)
	match_data.match_score.only_points_changed.connect(on_only_points_changed)
	match_data.match_score.games_changed.connect(on_MatchScore_games_changed)
	# the world starts the broadcast immediately after this call
	television.active_camera_changed.connect(on_Television_active_camera_changed)


func get_opponent(player):
	return players[1 - player.team_index]


func on_Television_active_camera_changed(camera: Camera3D):
	players[0].camera = camera


func set_state(new_state):
	state = new_state
	emit_signal("state_changed", state, new_state)
	if state == GlobalUtils.MatchStates.FAULT:
		print("Fault! Reason: ", fault_reason)

func get_fault_reason() -> String:
	return fault_reason

func on_Player_ready_to_serve():
	if state == GlobalUtils.MatchStates.IDLE:
		set_state(GlobalUtils.MatchStates.SERVE)
	elif state != GlobalUtils.MatchStates.SECOND_SERVE:
		print("ERROR!: on_Player_ready_to_serve")


func on_Player_ball_hit():
	if not ball_in_play:
		return

	if state == GlobalUtils.MatchStates.PLAY:
		if ground_contacts == 0:
			valid_side = GlobalUtils.get_opposite_side(valid_side)
		ground_contacts = 0

var last_ball_ground_pos: Vector3
func on_Ball_on_ground():
	if not ball_in_play:
		return
	last_ball_ground_pos = _active_ball.position
	print("on_Ball_on_ground")
	if state == GlobalUtils.MatchStates.SERVE:
		var valid = true
		if valid:
			ground_contacts += 1
			valid_side = GlobalUtils.get_opposite_side(valid_side)
			set_state(GlobalUtils.MatchStates.PLAY)
		else:
			_clear_active_ball()
			set_state(GlobalUtils.MatchStates.SECOND_SERVE)
	elif state == GlobalUtils.MatchStates.SECOND_SERVE:
		var valid = true
		if valid:
			ground_contacts += 1
			valid_side = GlobalUtils.get_opposite_side(valid_side)
			set_state(GlobalUtils.MatchStates.PLAY)
		else:
			fault_reason = "Double Fault"
			set_state(GlobalUtils.MatchStates.FAULT)
	elif state == GlobalUtils.MatchStates.PLAY:
		# check if current contact of the ball is valid:
		var valid = is_in_valid_side(_active_ball.position)
		if valid:
			ground_contacts += 1
			if ground_contacts < 2:
				valid_side = GlobalUtils.get_opposite_side(valid_side)
			else:
				fault_reason = "2 Ground Contacts"
				ground_contacts = 0
				set_state(GlobalUtils.MatchStates.FAULT)
		# we got an invalid contact
		else:
			if court.is_inside(_active_ball.position):
				fault_reason = "Wrong Side! Valid Side: " + str(valid_side) + " Actual Side: " + str(sign(_active_ball.position.z))
			else:
				fault_reason = "out"
			set_state(GlobalUtils.MatchStates.FAULT)

	if state == GlobalUtils.MatchStates.FAULT:
		ball_in_play = false
		var pointing_team = get_team_on_side(valid_side)
		match_data.add_point(pointing_team)
		valid_side = serve_direction
		_clear_active_ball()
		set_state(GlobalUtils.MatchStates.IDLE)
		world.stadium.start_serve_clocks()
	debug_print()

func is_in_valid_side(ball_pos: Vector3) -> bool:
	# Example of very bad code:
	if not court.is_inside(ball_pos):
		return false
	if (ball_pos.z < 0 and valid_side == 0) or (ball_pos.z > 0 and valid_side == 1):
		return true

	return false


func _clear_active_ball():
	_active_ball.on_ground.disconnect(on_Ball_on_ground)


func debug_print():
	print("---")
	print("STATE: ", state)
	print("valid side: ", valid_side)
	print("---")


func on_Player_ball_spawned(ball: Ball):
	_active_ball = ball
	_active_ball.on_ground.connect(on_Ball_on_ground)
	ball_in_play = true


func on_only_points_changed(score):
	pass
#	valid_side = GlobalUtils.get_opposite_side(valid_side)


func on_MatchScore_games_changed(score):
	players[0].is_serving = not players[0].is_serving
	players[1].is_serving = not players[1].is_serving
	# if the total number of games is odd, we need to change sides
	if ((score.games[0] + score.games[1]) % 2) == 1:
		players[0].rotate_y(PI)
		players[1].rotate_y(PI)
		team1_side = GlobalUtils.get_opposite_side(team1_side)
		team2_side = GlobalUtils.get_opposite_side(team2_side)
		players[0].position.z = -players[0].position.z
		players[1].position.z = -players[1].position.z
		valid_side = serve_direction
	elif ((score.games[0] + score.games[1]) % 2) == 0:
		serve_direction = GlobalUtils.get_opposite_side(serve_direction)


func get_serving_player_index():
	if players[0].is_serving:
		return 0
	else:
		return 1


func get_team_on_side(side: int) -> int:
	if team1_side == side:
		return 1
	else:
		return 2
