class_name MatchData
extends Resource

## Match time per point (s) between serves (walking back, toweling, serve preparation)
const SECONDS_PER_POINT: float = 25.0
## Match time per shot of a rally (s)
const SECONDS_PER_SHOT: float = 1.5
## Longest a single game can take (s)
const MAX_GAME_SECONDS: float = 600.0

var player0: PlayerData
var player1: PlayerData
var match_score: Score

var rally_length := 0
var longest_rally: int = 0
## Statistics per player [player0, player1]
var statistics: Array[MatchStatistics] = [MatchStatistics.new(), MatchStatistics.new()]
## Match time (s) shown in the stadium; advances after each game by the length of the game.
var elapsed_seconds: float = 0.0
var _game_seconds: float = 0.0


func _init(p_player0: PlayerData, p_player1: PlayerData) -> void:
	player0 = p_player0
	player1 = p_player1
	match_score = Score.new()


func get_score() -> Score:
	return match_score


func get_server() -> int:
	return match_score.current_server


func add_point(team_index: int) -> void:
	longest_rally = maxi(longest_rally, rally_length)
	_game_seconds += SECONDS_PER_POINT + rally_length * SECONDS_PER_SHOT
	var games_before: int = match_score.games_played
	match_score.add_point(team_index)
	if match_score.games_played > games_before:
		elapsed_seconds += minf(_game_seconds, MAX_GAME_SECONDS)
		_game_seconds = 0.0
