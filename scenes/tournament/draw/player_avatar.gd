## A player's round avatar on the draw: their initials on a circle (theme type Avatar) tinted
## in one of `colors`, the same for the player every time; an empty circle for a player not
## yet known.
class_name PlayerAvatar
extends PanelContainer

## Colors the circles are tinted in, picked per player
@export var colors: Array[Color] = [Palette.TEAL, Palette.RED, Palette.PURPLE, Color("#8a5a2b")]
@export var initials_font_size: int = 14

@onready var _initials_label: Label = %InitialsLabel


func _ready() -> void:
	_initials_label.add_theme_font_size_override(&"font_size", initials_font_size)


func show_player(player: PlayerData) -> void:
	if player == null:
		_initials_label.text = ""
		self_modulate = Palette.DEEP
		return
	_initials_label.text = player.first_name.left(1) + player.last_name.left(1)
	self_modulate = colors[posmod(hash(player.last_name), colors.size())]
