class_name UI extends CanvasLayer

@onready var score_label = $ScoreLabel
@onready var menu = $Menu


func update_score(score: String):
	score_label.text = score

func update_sets(sets: String):
	score_label.text = "%s" % [sets]


func show_menu():
	menu.visible = true
