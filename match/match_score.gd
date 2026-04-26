## Tennis match scoring system handling points, games, sets, and tiebreak logic
class_name Score
extends Resource

## Emitted when point score changes
signal score_changed

## Emitted when game score changes
signal game_changed

## Tennis point values for deuce/advantage tracking
enum TennisPoint { LOVE = 0, FIFTEEN = 1, THIRTY = 2, FORTY = 3, AD = 4 }

## Number of sets to win the match (typically 3 or 5)
var best_of_sets: int = 3

## Array of games won in each completed set
var games_in_set: Array[int] = []

## Current set score for each player [player0, player1]
var sets: Array[int] = [0, 0]

## Current game score for each player [player0, player1]
var games: Array[int] = [0, 0]

## Current point score for each player in standard tennis (0-40-AD)
var points: Array[int] = [0, 0]

## Point score during tiebreak (first to 7 with 2+ lead)
var tiebreak_points: Array[int] = [0, 0]

## Whether match is currently in tiebreak
var is_tiebreak: bool = false

## Index of current server (0 or 1)
var current_server: int = 0


## Record completed games to games_in_set array
func add_games_in_set(games_count: int) -> void:
	games_in_set.append(games_count)


## Process winning a game, handling set win and tiebreak transition
func add_game(player_index: int) -> void:
	# Check if we need to transition to tiebreak (both at 6 games)
	if games[player_index] == 6 and games[1 - player_index] == 6:
		is_tiebreak = true
		return
	# Winning condition: first to 6 games with 2+ game lead
	if games[player_index] >= 6:
		sets[player_index] += 1
		add_games_in_set(games[player_index])
		games = [0, 0]
	# Normal game win, continue set
	else:
		games[player_index] += 1
		current_server = 1 - current_server
		game_changed.emit()


## Process point scored during tiebreak (first to 7 with 2+ point lead)
func add_tiebreak_point(player_index: int) -> void:
	if abs(tiebreak_points[player_index] - tiebreak_points[1 - player_index]) < 2:
		tiebreak_points[player_index] += 1

	# Winning condition: 7+ points with 2+ point lead
	if (
		tiebreak_points[player_index] >= 7
		and tiebreak_points[player_index] - tiebreak_points[1 - player_index] >= 2
	):
		add_game(player_index)
		tiebreak_points = [0, 0]
		is_tiebreak = false


## Check if match has been won by either player
func is_match_over() -> bool:
	return sets[0] >= (best_of_sets + 1) / 2 or sets[1] >= (best_of_sets + 1) / 2


## Process point scored, handling tiebreak, deuce, and game win conditions
func add_point(player_index: int) -> void:
	if is_tiebreak:
		add_tiebreak_point(player_index)
		return

	# Deuce condition: both at 40 (FORTY enum value), player scored again
	if points[player_index] == TennisPoint.FORTY and points[1 - player_index] == TennisPoint.FORTY:
		points[player_index] += 1
	# Deuce: opponent had advantage, player tied it up
	elif points[player_index] == TennisPoint.FORTY and points[1 - player_index] == TennisPoint.AD:
		points[1 - player_index] -= 1
	# Win game: player had AD or 40 and scored again
	elif points[player_index] == TennisPoint.AD or points[player_index] == TennisPoint.FORTY:
		add_game(player_index)
		points = [0, 0]
	# Normal point progression
	else:
		points[player_index] += 1

	if is_match_over():
		return
	score_changed.emit()
