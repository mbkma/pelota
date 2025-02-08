class_name MatchManager
extends Node

enum MatchState { NOT_STARTED, IN_PROGRESS, GAME_OVER }

var current_state: MatchState = MatchState.NOT_STARTED
var last_hitter: Player  # Stores reference to last player who hit the ball

@onready var score: Score = $Score

@export var player0: Player
@export var player1: Player
@export var ball: Ball
@export var court: Court
@export var stadium: Stadium
@export var televisionHud: Control


func _ready() -> void:
	player0.ball_hit.connect(on_player0_ball_hit)
	player1.ball_hit.connect(on_player1_ball_hit)
	place_players()
	player0.is_serving = true


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			add_point(randi() % 2)
			print(score.sets)


func set_active_ball(b: Ball) -> void:
	ball = b
	ball.on_ground.connect(_on_ball_on_ground)


func on_player0_ball_hit():
	last_hitter = player0


func on_player1_ball_hit():
	last_hitter = player1


func get_opponent(player: Player) -> Player:
	if player == player0:
		return player1
	else:
		return player0


func start_match():
	current_state = MatchState.IN_PROGRESS
	# Initialize scoring and timers


func end_match(winner: String):
	current_state = MatchState.GAME_OVER


func reset_match():
	current_state = MatchState.NOT_STARTED
	# Reset scores and positions


func _on_ball_on_ground():
	if (
		court.is_ball_in_court_region(ball.position, court.CourtRegion.BACK_SINGLES_BOX)
		or court.is_ball_in_court_region(ball.position, court.CourtRegion.FRONT_SINGLES_BOX)
	):
		print("Ball landed inside the singles court.")
		return  # Rally continues

	# If the ball landed outside the court, the opponent wins
	var point_winner = get_opponent(last_hitter)
	print(point_winner.name, "wins the point!")


func add_point(winner: int):
	score.add_point(winner)
	place_players()


func place_players():
	var server = score.current_server  # 0 for Player 0, 1 for Player 1

	# Determine the number of games played in total
	var total_games = score.games[0] + score.games[1]
	var switch_sides = (total_games % 4) == 1 or (total_games % 4) == 2
	# Determine if the server serves from deuce (right) or ad (left)
	var total_points = score.points[0] + score.points[1]
	var server_on_deuce_side = (total_points % 2) == 0

	# Set default positions assuming server is on the front side
	var player0_position
	var player1_position
	if server == 0:
		player0_position = (
			stadium.StadiumPosition.SERVE_FRONT_RIGHT
			if server_on_deuce_side
			else stadium.StadiumPosition.SERVE_FRONT_LEFT
		)
		player1_position = (
			stadium.StadiumPosition.RECEIVE_BACK_LEFT
			if server_on_deuce_side
			else stadium.StadiumPosition.RECEIVE_BACK_RIGHT
		)
	else:
		player0_position = (
			stadium.StadiumPosition.RECEIVE_FRONT_RIGHT
			if server_on_deuce_side
			else stadium.StadiumPosition.RECEIVE_FRONT_LEFT
		)
		player1_position = (
			stadium.StadiumPosition.SERVE_BACK_LEFT
			if server_on_deuce_side
			else stadium.StadiumPosition.SERVE_BACK_RIGHT
		)

	# If sides are switched, adjust positions
	if switch_sides:
		if server == 0:
			player0_position = (
				stadium.StadiumPosition.SERVE_BACK_LEFT
				if server_on_deuce_side
				else stadium.StadiumPosition.SERVE_BACK_RIGHT
			)
			player1_position = (
				stadium.StadiumPosition.RECEIVE_FRONT_RIGHT
				if server_on_deuce_side
				else stadium.StadiumPosition.RECEIVE_FRONT_LEFT
			)
		else:
			player0_position = (
				stadium.StadiumPosition.RECEIVE_BACK_LEFT
				if server_on_deuce_side
				else stadium.StadiumPosition.RECEIVE_BACK_RIGHT
			)
			player1_position = (
				stadium.StadiumPosition.SERVE_FRONT_RIGHT
				if server_on_deuce_side
				else stadium.StadiumPosition.SERVE_FRONT_LEFT
			)

	# Assign positions to players using stadium positions dictionary
	# Use set_deferred to avoid collisions
	player0.set_deferred("global_position", stadium.positions[player0_position])
	player1.set_deferred("global_position", stadium.positions[player1_position])
	player0.rotation.y = PI if player0.position.z < 0 else 0
	player1.rotation.y = PI if player1.position.z < 0 else 0
