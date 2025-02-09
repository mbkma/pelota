class_name MatchData
extends Resource

signal completed

var player0: PlayerData
var player1: PlayerData
var match_score: Score

var rally_length := 0
var aces := 0

var server := 0


func _init(player0: PlayerData, player1: PlayerData) -> void:
	self.player0 = player0
	self.player1 = player1
	match_score = Score.new()


func get_score() -> Score:
	return match_score


func get_server() -> int:
	return match_score.current_server


func simulate_result() -> void:
	match_score.add_set([6, 0])
	match_score.add_set([6, 0])


func add_point(team_index: int) -> void:
	match_score.add_point(team_index)
