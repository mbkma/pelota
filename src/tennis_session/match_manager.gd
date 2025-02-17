class_name MatchManager
extends Node

signal state_changed
signal players_placed

enum MatchState { NOT_STARTED, IDLE, SERVE, SECOND_SERVE, PLAY, FAULT, GAME_OVER }

var last_hitter: Player  # Stores reference to last player who hit the ball
var state_history: Array[MatchState]

var current_state: MatchState = MatchState.NOT_STARTED:
	set(value):
		state_history.push_back(value)
		current_state = value
		state_changed.emit()

@onready var match_data: MatchData

@export var player0: Player
@export var player1: Player
@export var ball: Ball
@export var court: Court
@export var stadium: Stadium
@export var televisionHud: TelevisionHud
@export var umpire: Umpire

var _valid_serve_zone: Court.CourtRegion
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
	#state_changed.connect(_on_state_changed)
	place_players()
	start_match()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			add_point(randi() % 2)


func set_active_ball(b: Ball) -> void:
	ball = b
	ball.on_ground.connect(_on_ball_on_ground)
	ball.on_net.connect(_on_ball_on_net)


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

func set_player_serve():
	if match_data.get_server() == 0:
		player0.request_serve()
	else:
		player1.request_serve()

func start_match():
	_valid_serve_zone = Court.CourtRegion.BACK_SINGLES_BOX if get_server().position.z > 0 else Court.CourtRegion.FRONT_SINGLES_BOX
	_valid_rally_zone = _valid_serve_zone
	current_state = MatchState.SERVE
	set_player_serve()


func end_match(winner: String):
	current_state = MatchState.GAME_OVER


func reset_match():
	current_state = MatchState.NOT_STARTED
	# Reset scores and positions


func _swap_valid_rally_zone():
	_valid_rally_zone = (
		Court.CourtRegion.BACK_SINGLES_BOX
		if _valid_rally_zone == Court.CourtRegion.FRONT_SINGLES_BOX
		else Court.CourtRegion.FRONT_SINGLES_BOX
	)


func _on_ball_on_ground():
	if current_state == MatchState.IDLE:
		return
	elif current_state == MatchState.SERVE:
		var valid_box = get_valid_service_box()
		if court.is_ball_in_court_region(ball.position, valid_box):
			current_state = MatchState.PLAY
			_ground_contacts += 1
			_swap_valid_rally_zone()
		else:
			current_state = MatchState.SECOND_SERVE
			_clear_ball()
			if umpire:
				umpire.say_second_serve()
			set_player_serve()
	elif current_state == MatchState.SECOND_SERVE:
		var valid_box = get_valid_service_box()
		if court.is_ball_in_court_region(ball.position, valid_box):
			current_state = MatchState.PLAY
			_ground_contacts += 1
			_swap_valid_rally_zone()
		else:
			current_state = MatchState.FAULT
	elif current_state == MatchState.PLAY:
		if court.is_ball_in_court_region(ball.position, _valid_rally_zone):
			_ground_contacts += 1
			if _ground_contacts < 2:
				_swap_valid_rally_zone()
			else:
				current_state = MatchState.FAULT
		else:
			current_state = MatchState.FAULT

	if current_state == MatchState.FAULT:
		_stop_players()
		_clear_ball()
		if umpire:
			umpire.say_fault()

		var point_winner: Player
		if _ground_contacts == 0:
			point_winner = get_opponent(last_hitter)
			print(point_winner.name, " wins the point!", _ground_contacts)
		else:
			point_winner = last_hitter
			print(point_winner.name, " wins the point!", _ground_contacts)

		current_state = MatchState.IDLE
		_valid_rally_zone = _valid_serve_zone
		add_point(get_player_index(point_winner))

func _stop_players():
	player0.stop()
	player1.stop()

func _on_ball_on_net():
	if current_state == MatchState.SERVE:
		current_state = MatchState.SECOND_SERVE
		_clear_ball()
		if umpire:
			umpire.say_second_serve()
	elif current_state == MatchState.SECOND_SERVE:
		current_state = MatchState.FAULT
		# ball gets cleared in _on_ground

func add_point(winner: int):
	match_data.add_point(winner)
	televisionHud.update_score(match_data.get_score())
	if umpire:
		umpire.say_score(match_data.get_score())
	await get_tree().create_timer(3).timeout
	place_players()
	await players_placed
	_valid_serve_zone = Court.CourtRegion.BACK_SINGLES_BOX if get_server().position.z > 0 else Court.CourtRegion.FRONT_SINGLES_BOX
	current_state = MatchState.SERVE
	set_player_serve()

func get_server():
	var server = match_data.match_score.current_server
	if server == 0:
		return player0
	else:
		return player1

func _clear_ball():
	if ball:
		ball.on_ground.disconnect(_on_ball_on_ground)


func is_serve_from_deuce_side() -> bool:
	# Returns true if server serves from deuce side
	var score = match_data.get_score()
	var total_points = score.points[0] + score.points[1]
	return (total_points % 2) == 0


func get_valid_service_box() -> Court.CourtRegion:
	var serve_from_deuce_side = is_serve_from_deuce_side()

	var valid_service_box: Court.CourtRegion
	if _valid_serve_zone == Court.CourtRegion.BACK_SINGLES_BOX:
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
	var serve_from_deuce_side = is_serve_from_deuce_side()

	# Set default positions
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
	# Wait one frame to avoid collisions
	await get_tree().physics_frame
	player1.global_position = stadium.positions[player1_position]
	player0.rotation.y = PI if player0.position.z < 0 else 0.0
	player1.rotation.y = PI if player1.position.z < 0 else 0.0
	players_placed.emit()

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
