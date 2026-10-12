## Tabs of the options menu, in the main menu and the pause menu. The shoulder buttons and
## Page Up / Page Down switch tabs. They are read in _input, before the focused control: a tree
## or a scroll container would take them for scrolling. A dialog of a tab (such as the one
## assigning a new input) keeps them.
extends TabContainer


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _is_dialog_focused():
		return
	var step: int = UiPage.step(event)
	if step == 0:
		return
	current_tab = UiPage.next_tab(current_tab, step, get_tab_count(), is_tab_disabled)
	get_viewport().set_input_as_handled()


## Whether the focus is in a dialog opened in one of the tabs
func _is_dialog_focused() -> bool:
	var node: Node = get_viewport().gui_get_focus_owner()
	if node == null or not is_ancestor_of(node):
		return false
	while node != self:
		if node is OverlaidWindow and node.is_visible_in_tree():
			return true
		node = node.get_parent()
	return false
