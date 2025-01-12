class_name Game
extends Node

var state: String = "idle"

# Player and ball nodes
@onready var player1: Player = $Player1
@onready var player2: Player = $Player2
@onready var ball: Ball = $Ball
@onready var ui: UI = $Ui
@onready var tennis_court: TennisCourt = $TennisCourt

# Scoring system
var score: Score = Score.new()

func _ready():
	start_game()

# Start a new game
func start_game():
	state = "playing"
	score.best_of_sets = 5  # Set to best of 5 (or 3 as needed)
	#reset_ball()
	ui.update_score(score.get_scores_as_string())
	#place_players()

# End the game
func end_game():
	state = "ended"
	ui.show_final_score(score.sets_p1, score.sets_p2)

# Update the score when a player wins a point
func update_score(player: int):
	score.update_score(player)
	ui.update_score(score.get_scores_as_string())


	# Check if the match has been won
	if score.is_match_over():
		end_game()
	else:
		place_players()

# Check if the ball is out of bounds, and award the point to the other player
func check_point(ball_position: Vector3):
	if not tennis_court.is_in_bounds(ball_position):
		if ball_position.x > 0:
			update_score(1)  # Point for player 1
		else:
			update_score(2)  # Point for player 2
		reset_ball()

# Reset the ball for the next point
func reset_ball():
	ball.position = Vector3(0, 1, 0)  # Reset to a central position, slightly above ground
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO

# Place players based on the score for serve/return positions
func place_players():
	var current_game = score.games_p1 + score.games_p2
	if score.is_player_serving(1):
		player1.global_transform.origin = tennis_court.get_serve_position(1, current_game)
		player2.global_transform.origin = tennis_court.get_return_position(2, current_game)
	else:
		player2.global_transform.origin = tennis_court.get_serve_position(2, current_game)
		player1.global_transform.origin = tennis_court.get_return_position(1, current_game)
