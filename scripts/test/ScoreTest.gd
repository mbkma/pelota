extends Node

# Instance of Score class to test
var score: Score

func _ready():
	# Create a new Score instance before each test
	score = Score.new()
	run_tests()

func run_tests():
	test_point_scoring()
	#test_game_winning()
	#test_set_winning()
	#test_match_winning_best_of_three()
	#test_match_winning_best_of_five()
	print("All tests passed!")

# Test point scoring
func test_point_scoring():
	# Reset score and check initial points
	score.reset_points()
	assert(score.points_p1 == Score.TennisScore.LOVE, "Expected Player 1 points to be LOVE")
	assert(score.points_p2 == Score.TennisScore.LOVE, "Expected Player 2 points to be LOVE")

	# Player 1 wins points
	score.update_score(1)
	assert(score.points_p1 == Score.TennisScore.FIFTEEN, "Expected Player 1 points to be FIFTEEN")
	score.update_score(1)
	assert(score.points_p1 == Score.TennisScore.THIRTY, "Expected Player 1 points to be THIRTY")
	score.update_score(1)
	assert(score.points_p1 == Score.TennisScore.FORTY, "Expected Player 1 points to be FORTY")

	# Player 2 wins points
	score.update_score(2)
	assert(score.points_p2 == Score.TennisScore.FIFTEEN, "Expected Player 2 points to be FIFTEEN")
	score.update_score(2)
	assert(score.points_p2 == Score.TennisScore.THIRTY, "Expected Player 2 points to be THIRTY")
	score.update_score(2)
	assert(score.points_p2 == Score.TennisScore.FORTY, "Expected Player 2 points to be FORTY")

	# Check deuce scenario
	score.update_score(1)  # Player 1 gains advantage
	assert(score.advantage == 1, "Expected Player 1 to have advantage")

	score.update_score(2)  # Back to deuce
	assert(score.advantage == 0, "Expected no advantage (back to deuce)")

	print("test_point_scoring passed")
