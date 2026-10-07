## Stadium panel showing the speed of the last serve in mph.
class_name ServeSpeedPanel
extends Node3D

const MS_TO_MPH: float = 2.237
## Seconds the speed is shown
const SHOW_TIME: float = 5.0

@onready var _speed_label: Label3D = $Speed


func _ready() -> void:
	_speed_label.visible = false


## Shows `speed` (m/s) after a short, random delay.
func show_serve_speed(speed: float) -> void:
	await get_tree().create_timer(randf_range(1.0, 2.0)).timeout
	_speed_label.text = str(int(speed * MS_TO_MPH))
	_speed_label.show()
	await get_tree().create_timer(SHOW_TIME).timeout
	_speed_label.hide()
