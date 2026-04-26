@tool
class_name CrowdBlock
extends Node3D

## Crowd block system that manages groups of spectator animations

## Configuration resource for this block
@export var config: CrowdConfig:
	set(value):
		if config:
			if config.changed.is_connected(_on_config_changed):
				config.changed.disconnect(_on_config_changed)
			var old_palette = config.get_color_palette()
			if old_palette and old_palette.changed.is_connected(_on_config_changed):
				old_palette.changed.disconnect(_on_config_changed)
		config = value
		if Engine.is_editor_hint():
			_setup_config_signal()
			call_deferred("_regenerate_crowd")

## Scene to instantiate for each crowd member
@export var crowd_person_scene: PackedScene

## Container node for all crowd members in this block
var _people_container: Node3D

## List of all crowd members in this block
var _crowd_members: Array[CrowdPerson] = []



func _enter_tree() -> void:
	if Engine.is_editor_hint():
		call_deferred("_regenerate_crowd")
		_setup_config_signal()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		if config:
			if config.changed.is_connected(_on_config_changed):
				config.changed.disconnect(_on_config_changed)
			var palette = config.get_color_palette()
			if palette and palette.changed.is_connected(_on_config_changed):
				palette.changed.disconnect(_on_config_changed)
		cleanup()


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if not config:
		push_error("CrowdBlock: No configuration resource assigned")
		return

	if not config.validate():
		push_error("CrowdBlock: Invalid configuration")
		return

	if not crowd_person_scene:
		push_error("CrowdBlock: No crowd_person_scene assigned")
		return

	_create_people_container()
	_generate_crowd_grid()
	_initialize_animations()



## Tool function to regenerate the crowd preview in editor
func regenerate_preview() -> void:
	if Engine.is_editor_hint():
		call_deferred("_regenerate_crowd")


## Play random idle animation for a crowd member
func _play_random_idle_animation(person: CrowdPerson) -> void:
	if not person or not person.animation_state_machine:
		return

	if not person.play_idle_animation():
		# Animation was skipped (either error or LOD chance failed)
		return

	person.setup_idle_loop()


## Play victory celebration animations for all crowd members
func play_victory() -> void:
	for person in _crowd_members:
		if person and person.animation_state_machine:
			person.play_victory_animation()


## Cleanup all crowd members and resources
func cleanup() -> void:
	for person in _crowd_members:
		if person:
			person.cleanup()
	_crowd_members.clear()
	if _people_container:
		if Engine.is_editor_hint():
			_people_container.free()
		else:
			_people_container.queue_free()


# Private methods

func _regenerate_crowd() -> void:
	if not config or not _is_config_valid():
		return

	if not crowd_person_scene:
		return

	# Clean up existing crowd
	cleanup()

	# Generate new crowd
	_create_people_container()
	_generate_crowd_grid()

	# Initialize animations for both editor and runtime
	_initialize_animations()


func _create_people_container() -> void:
	_people_container = Node3D.new()
	_people_container.name = "PeopleContainer"
	add_child(_people_container)


func _generate_crowd_grid() -> void:
	if not config:
		return

	var seat_position: Vector3 = Vector3.ZERO
	var grid_rows = config.grid_rows
	var grid_columns = config.grid_columns

	for _row in range(grid_rows):
		for _col in range(grid_columns):
			var person = _instantiate_crowd_person()
			if not person:
				continue

			person.position = seat_position
			_people_container.add_child(person)
			_crowd_members.append(person)

			seat_position.x += config.seat_spacing_x

		seat_position.x = 0.0
		seat_position.y += config.seat_spacing_y
		seat_position.z -= config.seat_spacing_z


func _instantiate_crowd_person() -> CrowdPerson:
	if not crowd_person_scene:
		return null

	var person: CrowdPerson = crowd_person_scene.instantiate()
	if not person:
		return null

	# Assign config and random model variant
	person.config = config

	# Safely get random model variant, with fallback
	if config.model_variants and not config.model_variants.is_empty():
		person.model_key = config.model_variants[randi() % config.model_variants.size()]
	else:
		person.model_key = "crowd-1"

	return person


func _initialize_animations() -> void:
	for person in _crowd_members:
		if person:
			_play_random_idle_animation(person)


func _is_config_valid() -> bool:
	if not config:
		return false

	# In editor, just check basic properties to avoid placeholder issues
	if Engine.is_editor_hint():
		return config.grid_rows > 0 and config.grid_columns > 0

	# At runtime, do full validation
	return config.validate()


func _setup_config_signal() -> void:
	if not config or not Engine.is_editor_hint():
		return
	if not config.changed.is_connected(_on_config_changed):
		config.changed.connect(_on_config_changed)

	# Also listen to color palette changes
	var palette = config.get_color_palette()
	if palette and not palette.changed.is_connected(_on_config_changed):
		palette.changed.connect(_on_config_changed)


func _on_config_changed() -> void:
	if Engine.is_editor_hint():
		_regenerate_crowd()
