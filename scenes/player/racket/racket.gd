## Tennis racket: frame and strings, textured by a player's appearance.
class_name Racket
extends MeshInstance3D

## Surfaces of the racket mesh
const STRINGS_SURFACE: int = 0
const FRAME_SURFACE: int = 1


## Shows the racket textures of `appearance` (a full appearance, see Model.appearance).
func show_appearance(appearance: PlayerAppearance) -> void:
	_texture_surface(FRAME_SURFACE, appearance.racket_texture)
	_texture_surface(STRINGS_SURFACE, appearance.racket_strings_texture)


func _texture_surface(surface: int, texture: Texture2D) -> void:
	var material := (mesh.surface_get_material(surface) as StandardMaterial3D).duplicate()
	material.albedo_texture = texture
	material.albedo_color = Color.WHITE
	set_surface_override_material(surface, material)
