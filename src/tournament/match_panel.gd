#class_name MatchPanel
extends MarginContainer

@onready var player_0_label: Label = $"%Player0Label"
@onready var player_1_label: Label = $"%Player1Label"
@onready var result_label: Label = $"%ResultLabel"

var _match: MatchData


func setup(m):
	_match = m
	player_0_label.text = m.player0.last_name
	player_1_label.text = m.player1.last_name
	m.completed.connect(on_Match_completed)


func on_Match_completed():
	result_label.text = str(_match.match_score.get_data())
	result_label.visible = true
