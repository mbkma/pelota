## The stadium behind the menus: its benches get a random racket and bag, of the same brand on
## each bench.
class_name MenuBackground
extends Node3D

@onready var _stadium: Stadium = $Stadium


func _ready() -> void:
	_stadium.show_random_bench_equipment()
