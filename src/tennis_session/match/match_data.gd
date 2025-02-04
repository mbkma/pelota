class_name MatchData
extends Node

signal completed

var player0: PlayerData
var player1: PlayerData
var match_score: MatchScore

var number_of_sets := 2

var rally_length := 0
var aces := 0
var serve_side := "AD"

var serve_sides = ["AD", "DEUCE"]


func _init(player0, player1):
	self.player0 = player0
	self.player1 = player1
	match_score = MatchScore.new()
	match_score.only_points_changed.connect(_on_MatchScore_only_points_changed)
	match_score.sets_changed.connect(_on_MatchScore_sets_changed)


func simulate_result() -> void:
	match_score.add_set([6, 0])
	match_score.add_set([6, 0])


func add_point(team_index) -> void:
	match_score.add_point(team_index - 1)


func _on_MatchScore_only_points_changed(score) -> void:
	serve_side = "DEUCE"


func _on_MatchScore_sets_changed(score) -> void:
	if match_score.get_data().size() >= 2:
		emit_signal("completed")
