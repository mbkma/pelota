## Tennis racket: frame and strings, textured by a racket design.
class_name Racket
extends MeshInstance3D

## Surfaces of the racket mesh
const STRINGS_SURFACE: int = 0
const FRAME_SURFACE: int = 1

## Middle of the strings, where the racket should meet the ball
@export var sweet_spot: Marker3D


## Shows the frame and strings of `design`.
func show_design(design: RacketDesign) -> void:
	_texture_surface(FRAME_SURFACE, design.frame_texture)
	_texture_surface(STRINGS_SURFACE, design.strings_texture)


func _texture_surface(surface: int, texture: Texture2D) -> void:
	var material := (mesh.surface_get_material(surface) as StandardMaterial3D).duplicate()
	material.albedo_texture = texture
	material.albedo_color = Color.WHITE
	set_surface_override_material(surface, material)
