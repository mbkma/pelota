class_name Score
extends Resource

signal score_changed
signal game_changed

enum TennisPoint { LOVE, FIFTEEN, THIRTY, FORTY, AD }

var best_of_sets := 3
var games_in_set := []
var sets := [0, 0]
var games := [0, 0]
var points := [0, 0]
var tiebreak_points := [0, 0]

var is_tiebreak = false

var current_server := 0


func add_games_in_set(games):
	games_in_set.append(games)


func add_game(index):
	# first check if we need a tiebreak
	if games[index] == 6 and games[1 - index] == 6:
		is_tiebreak = true
		return
	# winning condition
	elif games[index] >= 6:
		sets[index] += 1
		add_games_in_set(games)
		games = [0, 0]
	# if not, just add the games
	else:
		games[index] += 1
		current_server = 1 - current_server
		game_changed.emit()


func add_tiebreak_point(index):
	if abs(tiebreak_points[index] - tiebreak_points[1 - index]) < 2:
		tiebreak_points[index] += 1

	# winning condition
	if tiebreak_points[index] >= 7 and tiebreak_points[index] - tiebreak_points[1 - index] >= 2:
		add_game(index)
		tiebreak_points = [0, 0]
		is_tiebreak = false


func is_match_over() -> bool:
	return sets[0] >= (best_of_sets + 1) / 2 or sets[1] >= (best_of_sets + 1) / 2


func add_point(index):
	if is_tiebreak:
		add_tiebreak_point(index)
		return

	# deuce
	if points[index] == TennisPoint.FORTY and points[1 - index] == TennisPoint.FORTY:
		points[index] += 1
	# ad opponent
	elif points[index] == TennisPoint.FORTY and points[1 - index] == TennisPoint.AD:
		points[1 - index] -= 1
	# won game
	elif points[index] == TennisPoint.AD or points[index] == TennisPoint.FORTY:
		add_game(index)
		points = [0, 0]
	# just add point
	else:
		points[index] += 1

	if is_match_over():
		print("match over")
		return
	print("server", current_server)
	score_changed.emit()
