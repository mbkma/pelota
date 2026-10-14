## A rating of both players of the head to head (40 to 100) as bars growing from the middle;
## the lower one faded.
class_name RatingRow
extends VBoxContainer

@export var title: String = "Serve"
@export_range(0.0, 1.0) var lower_alpha: float = 0.5

@onready var _left_value_label: Label = %LeftValueLabel
@onready var _right_value_label: Label = %RightValueLabel
@onready var _left_bar: ProgressBar = %LeftBar
@onready var _right_bar: ProgressBar = %RightBar


func _ready() -> void:
	%TitleLabel.text = title


func show_ratings(left: float, right: float) -> void:
	_left_value_label.text = str(roundi(left))
	_right_value_label.text = str(roundi(right))
	_left_bar.value = left
	_right_bar.value = right
	_left_bar.modulate.a = 1.0 if left >= right else lower_alpha
	_right_bar.modulate.a = 1.0 if right >= left else lower_alpha
