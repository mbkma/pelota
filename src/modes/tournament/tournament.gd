class_name Tournament
extends Node

var singles_matches: Array

var number_of_players := 64


func _init():
	generate_matches()


func generate_matches():
	var players = GlobalGameData.player_data
	for i in range(0, players.size() - 1, 2):
		singles_matches.append(MatchData.new(players[i], players[i + 1]))


func next_round():
	for m in singles_matches:
		m.simulate_result()
