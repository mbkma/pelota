## Ground ring showing where the player should stand to meet the incoming ball, and a line along
## the range it may meet the ball from (from the earliest to the latest contact). Its color shows
## how well the player is positioned: far_color when far off, perfect_color when in place.
class_name IdealPositionMarker
extends Node3D

## Height (m) of the range line above the ground, and its shortest shown length (m)
const RANGE_HEIGHT: float = 0.05
const RANGE_MIN_LENGTH: float = 0.05

@export var far_color: Color = Color(0.9, 0.2, 0.15, 0.85)
@export var perfect_color: Color = Color(0.25, 0.85, 0.3, 0.85)

var _material: StandardMaterial3D

@onready var _ring: MeshInstance3D = $Ring
@onready var _range: MeshInstance3D = $Range


func _ready() -> void:
	# Each player's marker has its own color.
	_material = (_ring.mesh as PrimitiveMesh).material.duplicate()
	_ring.material_override = _material
	_range.material_override = _material


## Shows the range on the ground from `from` to `to`.
func show_range(from: Vector3, to: Vector3) -> void:
	var span := Vector3(to.x - from.x, 0.0, to.z - from.z)
	if span.length() < RANGE_MIN_LENGTH:
		hide_range()
		return
	var middle: Vector3 = (from + to) * 0.5
	middle.y = RANGE_HEIGHT
	var along: Basis = Basis.looking_at(span) * Basis.from_scale(Vector3(1.0, 1.0, span.length()))
	_range.global_transform = Transform3D(along, middle)
	_range.visible = true


func hide_range() -> void:
	_range.visible = false


## Colors the ring by positioning quality in [0, 1], through orange and yellow (by hue).
func set_quality(quality: float) -> void:
	_material.albedo_color = Color.from_ok_hsl(
		lerpf(far_color.ok_hsl_h, perfect_color.ok_hsl_h, quality),
		lerpf(far_color.ok_hsl_s, perfect_color.ok_hsl_s, quality),
		lerpf(far_color.ok_hsl_l, perfect_color.ok_hsl_l, quality),
		lerpf(far_color.a, perfect_color.a, quality)
	)
