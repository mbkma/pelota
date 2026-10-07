## TV style score overlay.
class_name TelevisionHud
extends Control

@onready var _score_display: ScoreDisplay = $ScoreDisplay


func set_player(player_index: int, player_data: PlayerData) -> void:
	_score_display.set_player(player_index, player_data)


func update_score(score: Score) -> void:
	_score_display.set_score(score)
