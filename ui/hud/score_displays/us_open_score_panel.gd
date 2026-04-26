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


## Update score display for given player index
func set_score(score: Score, player_index: int) -> void:
	var points: Array[int] = score.points
	var games: Array[int] = score.games
	var sets: Array[int] = score.games_in_set

	# Update current points display
	match points[player_index]:
		score.TennisPoint.LOVE:
			_points_label.text = "0"
		score.TennisPoint.FIFTEEN:
			_points_label.text = "15"
		score.TennisPoint.THIRTY:
			_points_label.text = "30"
		score.TennisPoint.FORTY:
			_points_label.text = "40"
		score.TennisPoint.AD:
			_points_label.text = "AD"

	# Update set and game labels
	for i in range(sets.size()):
		if i < _games_labels.size():
			_games_labels[i].text = str(sets[i])

	# Display current games in set
	if sets.size() < _games_labels.size():
		_games_labels[sets.size()].visible = true
		_games_labels[sets.size()].text = str(games[player_index])


## Update player information display (name, rank, country)
func set_player(player_data: PlayerData) -> void:
	$MarginContainer/HBoxContainer11/Ranking.text = str(player_data.rank)
	$MarginContainer/HBoxContainer11/Name.text = str(player_data.last_name)
	$MarginContainer/HBoxContainer11/Country.text = str(player_data.country)


## Show or hide serve indicator
func set_serve(is_serving: bool) -> void:
	_serve_indicator.visible = is_serving
