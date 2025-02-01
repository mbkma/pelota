class_name Entry
extends HBoxContainer

@onready var left: Label = $Desc
@onready var right: Label = $Cont

var label := ""
var text := ""


func _ready() -> void:
	$Desc.text = label
	$Cont.text = text


func _process(delta: float) -> void:
	right.text = text
