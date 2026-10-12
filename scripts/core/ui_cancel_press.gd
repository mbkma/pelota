@tool
class_name UiCancelPress
extends RefCounted
## Pairs the releases of ui_cancel with their presses for a menu that closes when ui_cancel is
## released. A press taken by another window never reaches the menu: an open dropdown list
## closes on the press, and the release that follows must not close the menu as well.

## Whether the menu saw ui_cancel pressed and not released yet
var _pressed: bool = false


## Whether `event` releases ui_cancel without the menu having seen it pressed; the menu ignores
## such a release. Call it with every event the menu receives.
func is_unpaired_release(event: InputEvent) -> bool:
	if event.is_action_pressed(&"ui_cancel"):
		_pressed = true
		return false
	if not event.is_action_released(&"ui_cancel"):
		return false
	var paired: bool = _pressed
	_pressed = false
	return not paired
