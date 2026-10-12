@tool
## The same prop at many places, drawn as one MultiMesh: one draw call per surface of the prop
## however many places there are. Its children (e.g. Marker3D) are the places: move, turn, add
## or remove them in the editor and the props follow. A prop faces the court along +Z.
class_name PropRow
extends Node3D

## Emitted when the places changed (in the editor)
signal places_changed

@export var prop_mesh: Mesh:
	set(value):
		prop_mesh = value
		if is_inside_tree():
			_rebuild()

## Draws the props; an internal child, so it is not saved with the scene
var _props := MultiMeshInstance3D.new()
## The places' transforms when the props were last placed
var _placed: Array[Transform3D] = []


func _ready() -> void:
	add_child(_props, false, Node.INTERNAL_MODE_FRONT)
	_rebuild()
	# Places only move in the editor.
	set_process(Engine.is_editor_hint())


func _enter_tree() -> void:
	child_order_changed.connect(_rebuild)


## The children are freed after the row left the tree: no more rebuilding then.
func _exit_tree() -> void:
	child_order_changed.disconnect(_rebuild)


func _process(_delta: float) -> void:
	if places() != _placed:
		_rebuild()


## The places, in this node's space.
func places() -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for child in get_children():
		if child is Node3D:
			result.append((child as Node3D).transform)
	return result


func _rebuild() -> void:
	_placed = places()
	var props := MultiMesh.new()
	props.transform_format = MultiMesh.TRANSFORM_3D
	props.mesh = prop_mesh
	props.instance_count = _placed.size()
	for i in _placed.size():
		props.set_instance_transform(i, _placed[i])
	_props.multimesh = props
	places_changed.emit()
