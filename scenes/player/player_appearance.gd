## Look of a player: modular meshes, textures and colors. A color tints its slot's texture;
## a slot without a texture shows the plain color.
## Every field left unset (null, or a color with alpha 0) is taken from the base appearance
## (see Model), so player appearances only need what makes them different.
class_name PlayerAppearance
extends Resource

## Color meaning "not set, use the base appearance's"
const UNSET_COLOR := Color(0, 0, 0, 0)

@export var body_mesh: Mesh
@export var shirt_mesh: Mesh
@export var shorts_mesh: Mesh
@export var shoes_mesh: Mesh
@export var hair_mesh: Mesh

## Skin of the body and the face
@export var skin_texture: Texture2D
@export var skin_color: Color = UNSET_COLOR

@export var shirt_texture: Texture2D
@export var shirt_color: Color = UNSET_COLOR

@export var shorts_texture: Texture2D
@export var shorts_color: Color = UNSET_COLOR

@export var shoes_texture: Texture2D
@export var shoes_color: Color = UNSET_COLOR

## Strand shape (alpha) of the hair cards; the hair color sets the hue
@export var hair_texture: Texture2D
@export var hair_color: Color = UNSET_COLOR

@export var racket_texture: Texture2D
@export var racket_strings_texture: Texture2D


## This appearance with every unset field taken from `base`.
func merged_onto(base: PlayerAppearance) -> PlayerAppearance:
	var merged: PlayerAppearance = base.duplicate()
	for property in get_property_list():
		if not property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			continue
		var value: Variant = get(property.name)
		var is_unset: bool = value == null or (value is Color and value == UNSET_COLOR)
		if not is_unset:
			merged.set(property.name, value)
	return merged
