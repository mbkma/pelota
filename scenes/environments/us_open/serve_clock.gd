## Serve clock in a top corner of the wall behind a baseline: white lettering counting down the
## seconds the server has left.
class_name ServeClock
extends Node3D

@onready var _seconds: Label3D = $Seconds


func _ready() -> void:
	set_running(false)


## Shows (or hides) the countdown.
func set_running(running: bool) -> void:
	_seconds.visible = running


func show_seconds(seconds: int) -> void:
	_seconds.text = str(seconds)
