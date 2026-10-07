@tool
class_name CrowdBlock
extends Node3D
## A grid of spectators laid out by its config. In the editor the grid is rebuilt whenever the
## config changes.

@export var config: CrowdConfig:
	set(value):
		if config and config.changed.is_connected(_rebuild):
			config.changed.disconnect(_rebuild)
		config = value
		if Engine.is_editor_hint() and config:
			config.changed.connect(_rebuild)
			_rebuild.call_deferred()

## Scene instantiated for each spectator
@export var crowd_person_scene: PackedScene

var _crowd_members: Array[CrowdPerson] = []


func _ready() -> void:
	_rebuild()


## Lets about `share` (0 to 1) of the spectators cheer.
func cheer(share: float) -> void:
	for person in _crowd_members:
		if randf() < share:
			person.play_victory_animation()


func _rebuild() -> void:
	for person in _crowd_members:
		person.free()
	_crowd_members.clear()

	for row in config.grid_rows:
		for column in config.grid_columns:
			var person: CrowdPerson = crowd_person_scene.instantiate()
			person.config = config
			person.position = Vector3(
				column * config.seat_spacing.x,
				row * config.seat_spacing.y,
				-row * config.seat_spacing.z
			)
			add_child(person)
			_crowd_members.append(person)
