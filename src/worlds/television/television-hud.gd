extends Control

@onready var ScoreDisplay = $USOpenScoreDisplay
@onready var MatchStatsPanel = $MatchStatsPanel

func setup_singles_match(singles_match) -> void:
	ScoreDisplay.setup_singles_match(singles_match)
	MatchStatsPanel.setup_singles_match(singles_match)
