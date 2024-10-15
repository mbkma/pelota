extends Node

class_name Score

# Enums for Tennis Score
enum TennisScore { LOVE, FIFTEEN, THIRTY, FORTY }

# Player scores
var points_p1: int = TennisScore.LOVE
var points_p2: int = TennisScore.LOVE

# Player games won in current set
var games_p1: int = 0
var games_p2: int = 0

# Sets won by each player
var sets_p1: int = 0
var sets_p2: int = 0

# Maximum sets to win for match
var best_of_sets: int = 3

# Advantage state
var advantage: int = 0  # 0 = no advantage, 1 = player 1, 2 = player 2

# Keep track of who is serving
var current_server: int = 1  # 1 = Player 1, 2 = Player 2

# Array to keep track of games won in each set
var games_per_set: Dictionary = {
	"Player 1": [],
	"Player 2": []
}

# Reset points for a new game
func reset_points():
	points_p1 = TennisScore.LOVE
	points_p2 = TennisScore.LOVE
	advantage = 0

# Reset games for a new set
func reset_games():
	games_p1 = 0
	games_p2 = 0

# Update scores and check for game win
func update_score(player: int):
	if player == 1:
		points_p1 += 1
		if points_p1 == TennisScore.FORTY and points_p2 == TennisScore.FORTY:
			advantage = 1  # Player 1 gains advantage
		elif points_p1 > TennisScore.FORTY:
			games_p1 += 1
			games_per_set["Player 1"].append(games_p1)
			reset_points()
			switch_server()  # Switch server after a game is won
	elif player == 2:
		points_p2 += 1
		if points_p2 == TennisScore.FORTY and points_p1 == TennisScore.FORTY:
			advantage = 2  # Player 2 gains advantage
		elif points_p2 > TennisScore.FORTY:
			games_p2 += 1
			games_per_set["Player 2"].append(games_p2)
			reset_points()
			switch_server()  # Switch server after a game is won
	
	# Check if game won
	check_game_win()

# Check for game win and reset scores accordingly
func check_game_win():
	if games_p1 >= 6 and games_p1 - games_p2 >= 2:
		sets_p1 += 1
		reset_games()
	elif games_p2 >= 6 and games_p2 - games_p1 >= 2:
		sets_p2 += 1
		reset_games()

# Switch the server after a game is won
func switch_server():
	current_server = 1 if current_server == 2 else 2

# Check who is serving
func is_player_serving(player: int) -> bool:
	return current_server == player

# Check if match is over
func is_match_over() -> bool:
	return sets_p1 >= (best_of_sets + 1) / 2 or sets_p2 >= (best_of_sets + 1) / 2

# Get scores as string for UI display
func get_scores_as_string() -> String:
	return "Player 1: " + str(sets_p1) + " sets, " + str(games_per_set["Player 1"]) + " games\n" + \
		"Player 2: " + str(sets_p2) + " sets, " + str(games_per_set["Player 2"]) + " games"

# Reset everything for a new match
func reset_all():
	reset_points()
	reset_games()
	sets_p1 = 0
	sets_p2 = 0
	games_per_set["Player 1"].clear()
	games_per_set["Player 2"].clear()
	current_server = 1  # Player 1 serves first
