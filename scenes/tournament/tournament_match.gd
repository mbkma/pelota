## One match of a tournament draw: its two players, and once played the winner and the score set
## by set.
class_name TournamentMatch
extends Resource

## Round of the draw (0: the first round)
@export var round_index: int = 0
## The two players, in draw order (the upper line first)
@export var players: Array[PlayerData] = []
## Index (0 or 1) of the winner in `players`; -1 while not played
@export var winner: int = -1
## The score, set by set, from the winner's side (e.g. "6-4 3-6 7-6")
@export var score: String = ""
## Games of each set as (players[0], players[1])
@export var set_games: Array[Vector2i] = []
## Points of each set's tiebreak as (players[0], players[1]); zero for a set without one
@export var set_tiebreaks: Array[Vector2i] = []


func is_played() -> bool:
	return winner != -1


func get_winner() -> PlayerData:
	return players[winner]


func get_loser() -> PlayerData:
	return players[1 - winner]


func has_player(player: PlayerData) -> bool:
	return players.has(player)


## The other player of the match than `player`.
func opponent_of(player: PlayerData) -> PlayerData:
	return players[1 - players.find(player)]


## Tiebreak points of the loser of set `set_index`'s tiebreak (shown as a small number next to
## their games), -1 if the set had no tiebreak.
func tiebreak_loser_points(set_index: int) -> int:
	if set_index >= set_tiebreaks.size() or set_tiebreaks[set_index] == Vector2i.ZERO:
		return -1
	var points: Vector2i = set_tiebreaks[set_index]
	return mini(points.x, points.y)


func sets_won(player_index: int) -> int:
	var won: int = 0
	for games in set_games:
		if games[player_index] > games[1 - player_index]:
			won += 1
	return won


## Records the result of `final_score`, in which player `winner_index` (index in `players`
## and in the score).
func record(winner_index: int, final_score: Score) -> void:
	winner = winner_index
	set_games = final_score.completed_sets.duplicate()
	set_tiebreaks = final_score.set_tiebreaks.duplicate()
	var sets: PackedStringArray = []
	for games in final_score.completed_sets:
		var won: int = games[winner_index]
		var lost: int = games[1 - winner_index]
		sets.append("%d-%d" % [won, lost])
	score = " ".join(sets)
