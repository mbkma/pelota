extends Control

@onready var score_panel1 = $VBoxContainer/USOpenScorePanel
@onready var score_panel2 = $VBoxContainer/USOpenScorePanel2

var players

func setup_singles_match(singles_match: SinglesMatch):
	singles_match.match_data.match_score.points_changed.connect(on_MatchScore_points_changed)
	singles_match.match_data.match_score.games_changed.connect(on_MatchScore_games_changed)
	players = singles_match.players
	set_players(singles_match.players[0], singles_match.players[1])
	score_panel1.set_serve(players[0].is_serving)
	score_panel2.set_serve(players[1].is_serving)

func on_MatchScore_points_changed(score):
	score_panel1.set_score(score, 0)
	score_panel2.set_score(score, 1)

func on_MatchScore_games_changed(score):
	score_panel1.set_serve(players[0].is_serving)
	score_panel2.set_serve(players[1].is_serving)

func set_players(player1, player2):
	score_panel1.set_player(player1)
	score_panel2.set_player(player2)
