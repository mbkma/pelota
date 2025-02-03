class_name List
extends VBoxContainer


func add_entry(left_text, right_text) -> Entry:
	var e = load("res://src/hud/entry.tscn").instantiate()
	add_child(e)
	e.left.text = str(left_text)
	e.right.text = str(right_text) if right_text else "Null"
	return e


func get_entry(index) -> Entry:
	return get_child(index)
