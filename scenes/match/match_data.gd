## Score, statistics and match time of a match; saved between points (see SavedMatch).
class_name MatchData
extends Resource

## Match time per point (s) between serves (walking back, toweling, serve preparation)
const SECONDS_PER_POINT: float = 25.0
## Match time per shot of a rally (s)
const SECONDS_PER_SHOT: float = 1.5
## Longest a single game can take (s)
const MAX_GAME_SECONDS: float = 600.0

@export var score := Score.new()
@export var longest_rally: int = 0
## Statistics per player [player0, player1]
@export var statistics: Array[MatchStatistics] = [MatchStatistics.new(), MatchStatistics.new()]
## Match time (s) shown in the stadium; advances after each game by the length of the game.
@export var elapsed_seconds: float = 0.0
@export var _game_seconds: float = 0.0

## Shots in the current rally, serve included (not saved: a match is saved between points)
var rally_length: int = 0


func get_server() -> int:
	return score.current_server


func add_point(team_index: int) -> void:
	longest_rally = maxi(longest_rally, rally_length)
	_game_seconds += SECONDS_PER_POINT + rally_length * SECONDS_PER_SHOT
	var games_before: int = score.games_played
	score.add_point(team_index)
	if score.games_played > games_before:
		elapsed_seconds += minf(_game_seconds, MAX_GAME_SECONDS)
		_game_seconds = 0.0
