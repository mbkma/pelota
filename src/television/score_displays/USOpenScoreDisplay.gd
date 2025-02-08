extends Control

@onready var player_1_score_panel: HBoxContainer = $VBoxContainer/Player1ScorePanel
@onready var player_2_score_panel: HBoxContainer = $VBoxContainer/Player2ScorePanel


func set_score(score: Score):
	player_1_score_panel.set_score(score, 0)
	player_2_score_panel.set_score(score, 1)
