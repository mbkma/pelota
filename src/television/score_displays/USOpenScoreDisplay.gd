class_name ScoreDisplay
extends Control

@onready var player_1_score_panel: PlayerScorePanel = $VBoxContainer/Player1ScorePanel
@onready var player_2_score_panel: PlayerScorePanel = $VBoxContainer/Player2ScorePanel

var _player_score_panels := [player_1_score_panel, player_2_score_panel]


func _set_score(score: Score):
	player_1_score_panel.set_score(score, 0)
	player_2_score_panel.set_score(score, 1)


func set_player(player_data: PlayerData, index: int):
	_player_score_panels[index].set_player(player_data)
