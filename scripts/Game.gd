class_name Game extends Node

var score_p1: int = 0
var score_p2: int = 0
var state: String = "idle"

@onready var player1: Player = $Player1
@onready var player2: Player = $Player2
@onready var ball: Ball = $Ball
@onready var ui: UI = $Ui
@onready var tennis_court: TennisCourt = $TennisCourt


func _ready():
	start_game()


func start_game():
	state = "playing"
	score_p1 = 0
	score_p2 = 0
	#reset_ball()
	ui.update_score(score_p1, score_p2)


func end_game():
	state = "ended"
	# Show final score and reset game


func update_score(player: int):
	if player == 1:
		score_p1 += 1
	else:
		score_p2 += 1
	ui.update_score(score_p1, score_p2)


func check_point(ball_position: Vector3):
	if not tennis_court.is_in_bounds(ball_position):
		if ball_position.x > 0:
			update_score(1)  # Point for player 1
		else:
			update_score(2)  # Point for player 2
		reset_ball()


func reset_ball():
	ball.position = Vector3(0, 1, 0)  # Reset to a central position, slightly above ground
	ball.velocity = Vector3.ZERO
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
