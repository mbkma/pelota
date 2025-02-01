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


func set_score(score, index):
	var points = score.points
	var games = score.games
	var sets = score.sets

	# update points
	points_label.text = str(points[index])
	if points[index] == 45:
		points_label.text = "AD"

	#update game labels
	var labels = games_labels
	for i in range(sets.size()):
		labels[i].text = str(sets[i][index])
	labels[sets.size()].visible = true
	labels[sets.size()].text = str(games[index])


func set_player(player):
	$MarginContainer/HBoxContainer11/Ranking.text = str(player.player_data.rank)
	$MarginContainer/HBoxContainer11/Name.text = player.player_data.last_name
	$MarginContainer/HBoxContainer11/Country.text = player.player_data.country


func set_serve(is_serving: bool) -> void:
	serve_indicator.visible = is_serving
