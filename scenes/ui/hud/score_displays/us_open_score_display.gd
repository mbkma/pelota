## Score board with one row per player.
class_name ScoreDisplay
extends Control

@onready var _player_score_panels: Array[PlayerScorePanel] = [
	$VBoxContainer/Player1ScorePanel, $VBoxContainer/Player2ScorePanel
]


func set_score(score: Score) -> void:
	for i in _player_score_panels.size():
		_player_score_panels[i].set_score(score, i)


func set_player(player_index: int, player_data: PlayerData) -> void:
	_player_score_panels[player_index].set_player(player_data)
