extends Node
class_name MatchScore

signal sets_changed(_score)
signal games_changed(_score)
signal points_changed(_score)
signal only_points_changed(_score)

var _score: Dictionary = {
	"sets": [],
	"games": [0, 0],
	"points": [0, 0],
	"tiebreak_points": [0, 0],
}

var is_tiebreak = false


func get_data():
	return _score.sets


func add_set(games):
	_score.sets.append(games)
	emit_signal("sets_changed", _score)


func add_game(index):
	# first check if we need a tiebreak
	if _score.games[index] == 6 and _score.games[1 - index] == 6:
		is_tiebreak = true
		return
	# if not, just add the games
	elif _score.games[index] <= 6:
		_score.games[index] += 1

	# winning condition
	if _score.games[index] >= 6 and abs(_score.games[index] - _score.games[1 - index]) >= 2:
		add_set(_score.games)
		_score.games = [0, 0]
	emit_signal("games_changed", _score)


func add_tiebreak_point(index):
	if abs(_score.tiebreak_points[index] - _score.tiebreak_points[1 - index]) < 2:
		_score.tiebreak_points[index] += 1

	# winning condition
	if (
		_score.tiebreak_points[index] >= 7
		and _score.tiebreak_points[index] - _score.tiebreak_points[1 - index] >= 2
	):
		add_game(index)
		_score.tiebreak_points = [0, 0]
		is_tiebreak = false


func add_point(index):

	if is_tiebreak:
		add_tiebreak_point(index)
		return

	if _score.points[index] < 30:
		_score.points[index] += 15
	elif _score.points[index] == 30:
		_score.points[index] += 10
	# deuce
	elif _score.points[index] == 40 and _score.points[1 - index] == 40:
		_score.points[index] += 5
	elif _score.points[index] == 40 and _score.points[1 - index] == 45:
		_score.points[1 - index] -= 5
	elif _score.points[index] == 45:
		_score.points[index] += 5
	# won
	elif _score.points[index] == 40:
		_score.points[index] += 10
	# winning condition
	if _score.points[index] == 50 and abs(_score.points[index] - _score.points[1 - index]) >= 10:
		add_game(index)
		_score.points = [0, 0]
	else:
		emit_signal("only_points_changed", _score)

	emit_signal("points_changed", _score)


func is_points_diff_even() -> bool:
	return (abs(_score.points[0] - _score.points[1]) == 0) or (abs(_score.points[0] - _score.points[1]) == 30) or (abs(_score.points[0] - _score.points[1]) == 25)
