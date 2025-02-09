class_name MatchManager
extends Node

signal state_changed

enum MatchState { NOT_STARTED, IDLE, SERVE, SECOND_SERVE, PLAY, FAULT, GAME_OVER }

var last_hitter: Player  # Stores reference to last player who hit the ball

var current_state: MatchState = MatchState.NOT_STARTED:
	set(value):
		current_state = value
		state_changed.emit()

@onready var match_data: MatchData

@export var player0: Player
@export var player1: Player
@export var ball: Ball
@export var court: Court
@export var stadium: Stadium
@export var televisionHud: TelevisionHud

var _valid_court_region: Court.CourtRegion
var _valid_rally_zone: Court.CourtRegion
var _ground_contacts := 0


func _ready() -> void:
	if not player0 or not player1 or not court or not stadium or not televisionHud:
		printerr(self, ": Not properly initialized!")
		return
	match_data = MatchData.new(player0.player_data, player1.player_data)
	player0.ball_hit.connect(_on_player0_ball_hit)
	player1.ball_hit.connect(_on_player1_ball_hit)
	televisionHud.score_display.player_1_score_panel.set_player(player0.player_data)
	televisionHud.score_display.player_2_score_panel.set_player(player1.player_data)
	state_changed.connect(_on_state_changed)
	place_players()
	start_match()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			add_point(randi() % 2)
			print(match_data.get_score().sets)


func set_active_ball(b: Ball) -> void:
	ball = b
	ball.on_ground.connect(_on_ball_on_ground)


#func get_server() -> Player:
#if match_data.get_server() == 0:
#return player1
#else:
#return player0


func get_opponent(player: Player) -> Player:
	if player == player0:
		return player1
	else:
		return player0


func get_player_index(player: Player) -> int:
	if player == player0:
		return 0
	else:
		return 1


func _on_state_changed():
	if current_state == MatchState.SERVE:
		_set_player_is_serving(true)
	elif current_state == MatchState.SECOND_SERVE:
		_set_player_is_serving(true)
	elif current_state == MatchState.PLAY:
		_set_player_is_serving(false)
	else:
		_set_player_is_serving(false)


func _set_player_is_serving(is_serving: bool) -> void:
	if is_serving:
		if match_data.get_server() == 0:
			player0.is_serving = true
			player0.serve_requested.emit()
		else:
			player1.is_serving = true
			player1.serve_requested.emit()
	else:
		player0.is_serving = false
		player1.is_serving = false


func start_match():
	_valid_rally_zone = Court.CourtRegion.BACK_SINGLES_BOX
	current_state = MatchState.SERVE


func end_match(winner: String):
	current_state = MatchState.GAME_OVER


func reset_match():
	current_state = MatchState.NOT_STARTED
	# Reset scores and positions


func _swap_valid_rally_zone():
	print("_swap_valid_rally_zone from ", _valid_rally_zone)
	_valid_rally_zone = (
		Court.CourtRegion.BACK_SINGLES_BOX
		if _valid_rally_zone == Court.CourtRegion.FRONT_SINGLES_BOX
		else Court.CourtRegion.FRONT_SINGLES_BOX
	)
	print("to ", _valid_rally_zone)


func _on_ball_on_ground():
	if current_state == MatchState.IDLE:
		return
	elif current_state == MatchState.SERVE:
		var valid_box = get_valid_service_box()
		if court.is_ball_in_court_region(ball.position, valid_box):
			print("Ball landed in valid service box.")
			current_state = MatchState.PLAY
			_ground_contacts += 1
			_swap_valid_rally_zone()
		else:
			current_state = MatchState.SECOND_SERVE
	elif current_state == MatchState.SECOND_SERVE:
		var valid_box = get_valid_service_box()
		if court.is_ball_in_court_region(ball.position, valid_box):
			print("Ball landed in valid service box.")
			current_state = MatchState.PLAY
			_ground_contacts += 1
			_swap_valid_rally_zone()
		else:
			current_state = MatchState.FAULT

	elif current_state == MatchState.PLAY:
		if court.is_ball_in_court_region(ball.position, _valid_rally_zone):
			_ground_contacts += 1
			if _ground_contacts < 2:
				print("Ball landed in valid rally zone.")
				_swap_valid_rally_zone()
			else:
				print("Double bounce!")
				current_state = MatchState.FAULT
		else:
			print("Invalid rally zone! ", _valid_rally_zone)
			current_state = MatchState.FAULT

	if current_state == MatchState.FAULT:
		current_state = MatchState.IDLE
		var point_winner: Player
		if _ground_contacts == 0:
			point_winner = get_opponent(last_hitter)
			print(point_winner.name, " wins the point!", _ground_contacts)
		else:
			point_winner = last_hitter
			print(point_winner.name, " wins the point!", _ground_contacts)

		add_point(get_player_index(point_winner))


func add_point(winner: int):
	match_data.add_point(winner)
	place_players()
	televisionHud.update_score(match_data.get_score())
	if ball:
		ball.on_ground.disconnect(_on_ball_on_ground)
	current_state = MatchState.SERVE


func serve_from_deuce_side() -> bool:
	# Returns true if server serves from deuce side
	var score = match_data.get_score()
	var total_points = score.points[0] + score.points[1]
	return (total_points % 2) == 0


func get_valid_service_box() -> Court.CourtRegion:
	var server = match_data.get_server()  # 0 for Player 0, 1 for Player 1
	var score = match_data.get_score()
	var serve_from_deuce_side = serve_from_deuce_side()

	var valid_service_box: Court.CourtRegion
	if _valid_rally_zone == Court.CourtRegion.BACK_SINGLES_BOX:
		valid_service_box = (
			Court.CourtRegion.LEFT_BACK_SERVICE_BOX
			if serve_from_deuce_side
			else Court.CourtRegion.RIGHT_BACK_SERVICE_BOX
		)
	else:
		valid_service_box = (
			Court.CourtRegion.RIGHT_FRONT_SERVICE_BOX
			if serve_from_deuce_side
			else Court.CourtRegion.LEFT_FRONT_SERVICE_BOX
		)

	return valid_service_box


func place_players():
	var server = match_data.get_server()  # 0 for Player 0, 1 for Player 1
	var score = match_data.get_score()
	# Determine the number of games played in total
	var total_games = score.games[0] + score.games[1]
	var switch_sides = (total_games % 4) == 1 or (total_games % 4) == 2
	var serve_from_deuce_side = serve_from_deuce_side()

	# Set default positions assuming server is on the front side
	var player0_position
	var player1_position
	if server == 0:
		player0_position = (
			stadium.StadiumPosition.SERVE_FRONT_RIGHT
			if serve_from_deuce_side
			else stadium.StadiumPosition.SERVE_FRONT_LEFT
		)
		player1_position = (
			stadium.StadiumPosition.RECEIVE_BACK_LEFT
			if serve_from_deuce_side
			else stadium.StadiumPosition.RECEIVE_BACK_RIGHT
		)
	else:
		player0_position = (
			stadium.StadiumPosition.RECEIVE_FRONT_RIGHT
			if serve_from_deuce_side
			else stadium.StadiumPosition.RECEIVE_FRONT_LEFT
		)
		player1_position = (
			stadium.StadiumPosition.SERVE_BACK_LEFT
			if serve_from_deuce_side
			else stadium.StadiumPosition.SERVE_BACK_RIGHT
		)

	# If sides are switched, adjust positions
	if switch_sides:
		if server == 0:
			player0_position = (
				stadium.StadiumPosition.SERVE_BACK_LEFT
				if serve_from_deuce_side
				else stadium.StadiumPosition.SERVE_BACK_RIGHT
			)
			player1_position = (
				stadium.StadiumPosition.RECEIVE_FRONT_RIGHT
				if serve_from_deuce_side
				else stadium.StadiumPosition.RECEIVE_FRONT_LEFT
			)
		else:
			player0_position = (
				stadium.StadiumPosition.RECEIVE_BACK_LEFT
				if serve_from_deuce_side
				else stadium.StadiumPosition.RECEIVE_BACK_RIGHT
			)
			player1_position = (
				stadium.StadiumPosition.SERVE_FRONT_RIGHT
				if serve_from_deuce_side
				else stadium.StadiumPosition.SERVE_FRONT_LEFT
			)

	# Assign positions to players using stadium positions dictionary
	player0.global_position = stadium.positions[player0_position]
	player1.global_position = stadium.positions[player1_position]
	# Wait one frame to avoid collisions
	await get_tree().physics_frame
	player0.rotation.y = PI if player0.position.z < 0 else 0
	print("player0.position.z", player1.position.z)
	player1.rotation.y = PI if player1.position.z < 0 else 0
	print("player0.rotation.y", player1.rotation.y)


## Callback functions
#####################


func _on_player0_ball_hit():
	# important for volley
	if current_state == MatchState.PLAY:
		if _ground_contacts == 0:
			_swap_valid_rally_zone()
			print("Player 0 made a volley")
		_ground_contacts = 0
	last_hitter = player0


func _on_player1_ball_hit():
	# important for volley
	if current_state == MatchState.PLAY:
		if _ground_contacts == 0:
			_swap_valid_rally_zone()
			print("Player 1 made a volley")
		_ground_contacts = 0
	last_hitter = player1
