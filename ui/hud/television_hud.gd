class_name TelevisionHud
extends Control

@onready var score_display: ScoreDisplay = $ScoreDisplay


func update_score(score: Score):
	score_display._set_score(score)
