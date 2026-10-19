## Look of a player's body (see Model): skin, eyes and hair, and the kit they wear. The body's
## shape, hair style and kit garments come from the player's body (see PlayerData.body).
## Every field left unset (null, or a color with alpha 0) is taken from the base appearance
## (see Model), so player appearances only need what makes them different.
class_name PlayerAppearance
extends Resource

## Color meaning "not set, use the base appearance's"
const UNSET_COLOR := Color(0, 0, 0, 0)

## Skin tone (from assets/textures/players/skin/) and a tint over it
@export var skin_texture: Texture2D
@export var skin_tint: Color = UNSET_COLOR
## Eye color (from assets/textures/players/eyes/)
@export var eye_texture: Texture2D
## Color of the hair, the eyebrows and the eyelashes
@export var hair_color: Color = UNSET_COLOR
@export var kit: KitDesign


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
