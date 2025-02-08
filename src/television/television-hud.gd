extends Control

@onready var score_display = $ScoreDisplay

@export var score: Score


func _ready() -> void:
	if score:
		score.changed.connect(on_score_changed)


func on_score_changed():
	score_display.set_score(score)
