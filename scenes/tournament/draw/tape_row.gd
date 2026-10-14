## A line of the head to head's tale of the tape: both players' values of `title`.
class_name TapeRow
extends HBoxContainer

@export var title: String = "Age"


func _ready() -> void:
	%TitleLabel.text = title


func show_values(left: String, right: String) -> void:
	%LeftValueLabel.text = left
	%RightValueLabel.text = right
