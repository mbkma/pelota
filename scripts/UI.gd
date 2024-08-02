extends CanvasLayer

class_name UI

@onready var score_label = $ScoreLabel
@onready var menu = $Menu

func update_score(score_p1: int, score_p2: int):
	score_label.text = "Player 1: %d - Player 2: %d" % [score_p1, score_p2]

func show_menu():
	menu.visible = true
