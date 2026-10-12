@tool
## A racket bag of a brand: the bag in the brand's colors, the brand's name on both sides. Pick
## the brand in the inspector; on a player's bench the stadium gives it the brand of the player's
## racket.
class_name TennisBag
extends MeshInstance3D

## Surfaces of the bag mesh (see CourtsidePropsBuilder)
const BODY_SURFACE: int = 0
const ACCENT_SURFACE: int = 1
## Per brand: its name as printed, and the colors of the body, the end panels and the strap, and
## the name
const LOOKS: Dictionary[RacketDesign.Brand, Array] = {
	RacketDesign.Brand.HEAD:
	["HEAD", Color(0.07, 0.07, 0.08), Color(0.92, 0.92, 0.92), Color(0.95, 0.95, 0.95)],
	RacketDesign.Brand.TECNIFIBRE:
	["TECNIFIBRE", Color(0.09, 0.09, 0.11), Color(0.8, 0.1, 0.15), Color(0.95, 0.95, 0.95)],
	RacketDesign.Brand.WILSON:
	["Wilson", Color(0.78, 0.07, 0.1), Color(0.92, 0.92, 0.92), Color(1, 1, 1)],
	RacketDesign.Brand.BABOLAT:
	["BABOLAT", Color(0.97, 0.83, 0.07), Color(0.08, 0.08, 0.08), Color(0.08, 0.08, 0.08)],
	RacketDesign.Brand.YONEX:
	["YONEX", Color(0.1, 0.3, 0.75), Color(0.92, 0.92, 0.92), Color(1, 1, 1)],
	RacketDesign.Brand.DUNLOP:
	["DUNLOP", Color(0.08, 0.08, 0.08), Color(0.82, 0.1, 0.16), Color(0.85, 0.1, 0.16)],
	RacketDesign.Brand.DIADEM:
	["DIADEM", Color(0.09, 0.6, 0.84), Color(0.08, 0.08, 0.08), Color(1, 1, 1)],
}

@export var brand: RacketDesign.Brand = RacketDesign.Brand.HEAD:
	set(value):
		brand = value
		if is_node_ready():
			_apply_brand()

@onready var _labels: Array[Label3D] = [$FrontLabel, $BackLabel]


func _ready() -> void:
	_apply_brand()


func _apply_brand() -> void:
	var look: Array = LOOKS[brand]
	set_surface_override_material(BODY_SURFACE, _material(look[1]))
	set_surface_override_material(ACCENT_SURFACE, _material(look[2]))
	for label in _labels:
		label.text = look[0]
		label.modulate = look[3]


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	return material
