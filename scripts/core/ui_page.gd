class_name UiPage
extends RefCounted
## Page switching of menus with tabs: the gamepad's shoulder buttons and Page Up / Page Down
## (ui_page_up and ui_page_down).


## -1 for ui_page_up, 1 for ui_page_down, 0 for any other event.
static func step(event: InputEvent) -> int:
	if event.is_action_pressed(&"ui_page_up"):
		return -1
	if event.is_action_pressed(&"ui_page_down"):
		return 1
	return 0


## The tab `step` tabs away from `current`, skipping disabled tabs and wrapping around;
## `current` when no other tab is enabled.
static func next_tab(current: int, step: int, tab_count: int, is_disabled: Callable) -> int:
	var tab: int = current
	for i in tab_count - 1:
		tab = posmod(tab + step, tab_count)
		if not is_disabled.call(tab):
			return tab
	return current
