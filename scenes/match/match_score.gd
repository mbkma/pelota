## Tennis match scoring system handling points, games, sets, tiebreaks and change of ends
class_name Score
extends Resource

## Emitted when point score changes
signal score_changed

## Emitted when game score changes
signal game_changed

## Tennis point values for deuce/advantage tracking
enum TennisPoint { LOVE = 0, FIFTEEN = 1, THIRTY = 2, FORTY = 3, AD = 4 }

## What winning the next point would decide for a player
enum PointImportance { NORMAL, GAME, BREAK, SET, MATCH }

## Games needed to win a set (a tiebreak is played at GAMES_PER_SET all)
const GAMES_PER_SET: int = 6
## Points needed to win a tiebreak (with a 2 point lead)
const TIEBREAK_POINTS: int = 7
## Ends change every this many points during a tiebreak
const TIEBREAK_END_CHANGE_POINTS: int = 6

## Number of sets to win the match (typically 3 or 5)
var best_of_sets: int = 3

## Games of each completed set as (player0, player1)
var completed_sets: Array[Vector2i] = []

## Sets won by each player [player0, player1]
var sets: Array[int] = [0, 0]

## Games of the current set for each player [player0, player1]
var games: Array[int] = [0, 0]

## Current point score for each player in standard tennis (0-40-AD)
var points: Array[int] = [0, 0]

## Point score during tiebreak (first to 7 with 2+ lead)
var tiebreak_points: Array[int] = [0, 0]

## Whether match is currently in tiebreak
var is_tiebreak: bool = false

## Index of current server (0 or 1)
var current_server: int = 0

## Games played in the whole match, used for the change of ends
var games_played: int = 0

## Player who served the first point of the current tiebreak
var _tiebreak_first_server: int = 0


## Check if match has been won by either player
func is_match_over() -> bool:
	var sets_to_win: int = ceili(best_of_sets / 2.0)
	return sets[0] >= sets_to_win or sets[1] >= sets_to_win


## Process point scored, handling tiebreak, deuce, and game win conditions
func add_point(player_index: int) -> void:
	if is_tiebreak:
		_add_tiebreak_point(player_index)
	else:
		_add_game_point(player_index)
	score_changed.emit()


## What winning the next point would decide for `player_index`.
func point_importance(player_index: int) -> PointImportance:
	var after: Score = _copy()
	after.add_point(player_index)
	if after.is_match_over():
		return PointImportance.MATCH
	if after.sets[player_index] > sets[player_index]:
		return PointImportance.SET
	if after.games_played > games_played:
		return PointImportance.GAME if player_index == current_server else PointImportance.BREAK
	return PointImportance.NORMAL


## Whether the receiver would win the server's game with the next point (not in a tiebreak).
func is_break_point() -> bool:
	if is_tiebreak:
		return false
	var after: Score = _copy()
	after.add_point(1 - current_server)
	return after.games_played > games_played


## Whether the next point is served from the deuce (right) side
func is_deuce_court() -> bool:
	var total_points: int = (
		tiebreak_points[0] + tiebreak_points[1] if is_tiebreak else points[0] + points[1]
	)
	return total_points % 2 == 0


## Whether the players have swapped ends relative to the start of the match.
## Ends change after every odd game of the match (so a set with an even number of games
## carries over into the next set) and every 6 points of a tiebreak.
func are_ends_switched() -> bool:
	var changes: int = floori((games_played + 1) / 2.0)
	if is_tiebreak:
		var tiebreak_total: int = tiebreak_points[0] + tiebreak_points[1]
		changes += floori(tiebreak_total / float(TIEBREAK_END_CHANGE_POINTS))
	return changes % 2 == 1


func _add_game_point(player_index: int) -> void:
	var opponent_index: int = 1 - player_index
	if points[player_index] == TennisPoint.FORTY and points[opponent_index] == TennisPoint.AD:
		# Back to deuce
		points[opponent_index] = TennisPoint.FORTY
	elif (
		points[player_index] == TennisPoint.AD
		or (points[player_index] == TennisPoint.FORTY and points[opponent_index] < TennisPoint.FORTY)
	):
		_win_game(player_index)
	else:
		points[player_index] += 1


func _add_tiebreak_point(player_index: int) -> void:
	tiebreak_points[player_index] += 1
	var lead: int = tiebreak_points[player_index] - tiebreak_points[1 - player_index]
	if tiebreak_points[player_index] >= TIEBREAK_POINTS and lead >= 2:
		is_tiebreak = false
		tiebreak_points = [0, 0]
		# The player who received first in the tiebreak serves first in the next set;
		# _win_game passes the serve on from the tiebreak's first server.
		current_server = _tiebreak_first_server
		_win_game(player_index)
		return

	# Serve changes after the first point, then every two points.
	if (tiebreak_points[0] + tiebreak_points[1]) % 2 == 1:
		current_server = 1 - current_server


func _win_game(player_index: int) -> void:
	points = [0, 0]
	games[player_index] += 1
	games_played += 1
	current_server = 1 - current_server

	var lead: int = games[player_index] - games[1 - player_index]
	if (games[player_index] >= GAMES_PER_SET and lead >= 2) or games[player_index] > GAMES_PER_SET:
		_win_set(player_index)
	elif games[0] == GAMES_PER_SET and games[1] == GAMES_PER_SET:
		is_tiebreak = true
		_tiebreak_first_server = current_server
	game_changed.emit()


func _win_set(player_index: int) -> void:
	completed_sets.append(Vector2i(games[0], games[1]))
	sets[player_index] += 1
	games = [0, 0]


func _copy() -> Score:
	var copy := Score.new()
	copy.best_of_sets = best_of_sets
	copy.completed_sets = completed_sets.duplicate()
	copy.sets = sets.duplicate()
	copy.games = games.duplicate()
	copy.points = points.duplicate()
	copy.tiebreak_points = tiebreak_points.duplicate()
	copy.is_tiebreak = is_tiebreak
	copy.current_server = current_server
	copy.games_played = games_played
	copy._tiebreak_first_server = _tiebreak_first_server
	return copy
