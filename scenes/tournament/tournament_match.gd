## One match of a tournament draw: its two players, and once played the winner and the score.
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


func is_played() -> bool:
	return winner != -1


func get_winner() -> PlayerData:
	return players[winner]


func has_player(player: PlayerData) -> bool:
	return players.has(player)


## Records the result of `final_score`, in which player `winner_index` (index in `players`
## and in the score) won.
func record(winner_index: int, final_score: Score) -> void:
	winner = winner_index
	var sets: PackedStringArray = []
	for games in final_score.completed_sets:
		var won: int = games[winner_index]
		var lost: int = games[1 - winner_index]
		sets.append("%d-%d" % [won, lost])
	score = " ".join(sets)
