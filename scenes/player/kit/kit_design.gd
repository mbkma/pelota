## What a player wears: the colors of each garment of the kit and the patterns they are laid out in
## (see scenes/player/materials/kit.gdshader). A pattern is a mask from assets/textures/players/kit/
## for its garment (made by tools/blender/make_player_textures.py): its green parts take the second
## color, its blue parts the trim color, the rest the main color; none is plain.
class_name KitDesign
extends Resource

@export_group("Shirt")
@export var shirt_pattern: Texture2D
@export var shirt_color: Color = Color.WHITE
@export var shirt_second_color: Color = Color(0.1, 0.12, 0.25)
@export var shirt_trim_color: Color = Color(0.1, 0.12, 0.25)

@export_group("Shorts")
@export var shorts_pattern: Texture2D
@export var shorts_color: Color = Color(0.1, 0.12, 0.25)
@export var shorts_second_color: Color = Color.WHITE
@export var shorts_trim_color: Color = Color.WHITE

@export_group("Socks")
@export var socks_pattern: Texture2D
@export var socks_color: Color = Color.WHITE
@export var socks_stripe_color: Color = Color(0.1, 0.12, 0.25)

@export_group("Shoes")
@export var shoes_color: Color = Color.WHITE
@export var shoes_sole_color: Color = Color(0.92, 0.92, 0.9)
@export var shoes_trim_color: Color = Color(0.1, 0.12, 0.25)

@export_group("Accessories")
@export var headband: bool = false
@export var wristbands: bool = false
@export var accessory_color: Color = Color.WHITE
