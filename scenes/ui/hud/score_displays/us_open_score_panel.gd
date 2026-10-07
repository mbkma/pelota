## Score display panel for singles match showing points, games, and sets
class_name PlayerScorePanel
extends Control

@onready var _games_labels: Array[Label] = [
	$MarginContainer2/HBoxContainer12/Games1,
	$MarginContainer2/HBoxContainer12/Games2,
	$MarginContainer2/HBoxContainer12/Games3,
	$MarginContainer2/HBoxContainer12/Games4,
	$MarginContainer2/HBoxContainer12/Games5,
]
@onready var _points_label: Label = $MarginContainer2/HBoxContainer12/MarginContainer/Points
@onready var _serve_indicator: Control = $MarginContainer/HBoxContainer11/ServeIndicator


## Shows the score of `player_index` and whether the player serves.
func set_score(score: Score, player_index: int) -> void:
	_serve_indicator.visible = score.current_server == player_index
	if score.is_tiebreak:
		_points_label.text = str(score.tiebreak_points[player_index])
	else:
		_points_label.text = _point_text(score.points[player_index])

	# One label per completed set, then the current set unless the match is over.
	var shown_sets: int = score.completed_sets.size()
	for i in _games_labels.size():
		var label: Label = _games_labels[i]
		if i < shown_sets:
			label.text = str(score.completed_sets[i][player_index])
			label.visible = true
		elif i == shown_sets and not score.is_match_over():
			label.text = str(score.games[player_index])
			label.visible = true
		else:
			label.visible = false


func _point_text(point: int) -> String:
	match point:
		Score.TennisPoint.FIFTEEN:
			return "15"
		Score.TennisPoint.THIRTY:
			return "30"
		Score.TennisPoint.FORTY:
			return "40"
		Score.TennisPoint.AD:
			return "AD"
	return "0"


## Update player information display (name, rank, country)
func set_player(player_data: PlayerData) -> void:
	$MarginContainer/HBoxContainer11/Ranking.text = str(player_data.rank)
	$MarginContainer/HBoxContainer11/Name.text = player_data.last_name
	$MarginContainer/HBoxContainer11/Country.text = player_data.country
