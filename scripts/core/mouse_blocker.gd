## Without a gamepad the mouse works as usual: visible in the menus, captured while a match or a
## training is played (see PlaySession) and shown again by the menus opening over it (see
## OverlaidWindow.makes_mouse_visible). With a gamepad connected the game is played with the
## gamepad: the mouse stays captured and its input is ignored, except while the debug HUD is open.
extends Node

var _debug_ui_open: bool = false


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


## Shows the cursor and lets mouse input pass while the debug HUD is open, also with a gamepad.
func set_debug_ui_open(open: bool) -> void:
	_debug_ui_open = open


## Whether the mouse is locked: captured and its input ignored
func is_locked() -> bool:
	return not _debug_ui_open and not Input.get_connected_joypads().is_empty()


## Menus set the mouse mode as they open and close; with a gamepad it stays captured. Runs before
## the scene nodes, so a menu opened by input or physics never shows the cursor for a frame.
func _process(_delta: float) -> void:
	if is_locked():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Runs after the _input of every scene node (autoloads come first in the tree), so it only
## keeps mouse events from the GUI and the unhandled input.
func _input(event: InputEvent) -> void:
	if event is InputEventMouse and is_locked():
		get_viewport().set_input_as_handled()


## The last gamepad gone, the mouse comes back.
func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	if Input.get_connected_joypads().is_empty():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
