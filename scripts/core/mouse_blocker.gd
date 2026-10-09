## The game is played with the keyboard and gamepads only: the mouse cursor stays hidden and
## mouse input does not reach the game or its menus. Debug tools that need the mouse make it
## visible (or capture it) while they are in use; mouse input passes then.
extends Node


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	get_tree().node_added.connect(_on_node_added)


## Runs after the _input of every scene node (autoloads come first in the tree), so it only
## keeps mouse events from the GUI and the unhandled input.
func _input(event: InputEvent) -> void:
	if event is InputEventMouse and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		get_viewport().set_input_as_handled()


## Overlaid windows (menus, dialogs) show the mouse cursor by default.
func _on_node_added(node: Node) -> void:
	if node is OverlaidWindow:
		node.makes_mouse_visible = false
