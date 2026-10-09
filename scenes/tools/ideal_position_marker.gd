## Ground ring showing where the player should stand to meet the incoming ball. Its color shows
## how well the player is positioned: far_color when far off, perfect_color when in place.
class_name IdealPositionMarker
extends Node3D

@export var far_color: Color = Color(0.9, 0.2, 0.15, 0.85)
@export var perfect_color: Color = Color(0.25, 0.85, 0.3, 0.85)

var _material: StandardMaterial3D

@onready var _ring: MeshInstance3D = $Ring


func _ready() -> void:
	# Each player's marker has its own color.
	_material = (_ring.mesh as PrimitiveMesh).material.duplicate()
	_ring.material_override = _material


## Colors the ring by positioning quality in [0, 1], through orange and yellow (by hue).
func set_quality(quality: float) -> void:
	_material.albedo_color = Color.from_ok_hsl(
		lerpf(far_color.ok_hsl_h, perfect_color.ok_hsl_h, quality),
		lerpf(far_color.ok_hsl_s, perfect_color.ok_hsl_s, quality),
		lerpf(far_color.ok_hsl_l, perfect_color.ok_hsl_l, quality),
		lerpf(far_color.a, perfect_color.a, quality)
	)
