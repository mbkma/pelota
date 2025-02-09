class_name PlayerScorePanel
extends Control

@onready var games_labels = [
	$MarginContainer2/HBoxContainer12/Games1,
	$MarginContainer2/HBoxContainer12/Games2,
	$MarginContainer2/HBoxContainer12/Games3,
	$MarginContainer2/HBoxContainer12/Games4,
	$MarginContainer2/HBoxContainer12/Games5,
]
@onready var points_label = $MarginContainer2/HBoxContainer12/Panel2/Points
@onready var serve_indicator = $MarginContainer/HBoxContainer11/ServeIndicator


func set_score(score: Score, index):
	var points = score.points
	var games = score.games
	var sets = score.games_in_set
	# update points
	if points[index] == score.TennisPoint.LOVE:
		points_label.text = "0"
	elif points[index] == score.TennisPoint.FIFTEEN:
		points_label.text = "15"
	elif points[index] == score.TennisPoint.THIRTY:
		points_label.text = "30"
	elif points[index] == score.TennisPoint.FORTY:
		points_label.text = "40"
	elif points[index] == score.TennisPoint.AD:
		points_label.text = "AD"

	#update game labels
	var labels = games_labels
	for i in range(sets.size()):
		labels[i].text = str(sets[i][index])
	labels[sets.size()].visible = true
	labels[sets.size()].text = str(games[index])


func set_player(player_data):
	$MarginContainer/HBoxContainer11/Ranking.text = str(player_data.rank)
	$MarginContainer/HBoxContainer11/Name.text = str(player_data.last_name)
	$MarginContainer/HBoxContainer11/Country.text = str(player_data.country)


func set_serve(is_serving: bool) -> void:
	serve_indicator.visible = is_serving
