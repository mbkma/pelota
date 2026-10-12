@tool
class_name OptionsWindow
extends OverlaidWindowContainer
## The options menu in a window, in the main menu and the pause menu. Releasing ui_cancel closes
## it only when it saw the press: closing an open dropdown list keeps it open.

var _cancel_press := UiCancelPress.new()


func _unhandled_input(event: InputEvent) -> void:
	if _cancel_press.is_unpaired_release(event):
		return
	super._unhandled_input(event)
