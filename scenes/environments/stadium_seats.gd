@tool
class_name StadiumSeats
extends Node3D
## Draws the seats of a stadium: one MultiMesh of seats per section of its seating.

@export var seating: StadiumSeating
@export var seat_mesh: Mesh


func _ready() -> void:
	for section in seating.sections:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = seat_mesh
		multimesh.instance_count = section.size()
		for i in section.size():
			multimesh.set_instance_transform(i, StadiumSeating.seat_transform(section[i]))
		var seats := MultiMeshInstance3D.new()
		seats.multimesh = multimesh
		seats.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(seats)
