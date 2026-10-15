## One control explained in the tutorial: what it does and its keyboard and gamepad buttons.
class_name TutorialControl
extends Resource

@export var description: String
## Keys of the keyboard only layout (see KeyboardInput.Layout)
@export var keyboard_icons: Array[Texture2D] = []
## Keys and mouse buttons of the keyboard and mouse layout; empty if they are keyboard_icons
@export var mouse_icons: Array[Texture2D] = []
@export var gamepad_icons: Array[Texture2D] = []
