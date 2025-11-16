class_name CrowdBlock
extends Node3D

## Crowd block system that manages groups of spectator animations

## Configuration resource for this block
@export var config: CrowdConfig

## Scene to instantiate for each crowd member
@export var crowd_person_scene: PackedScene

## Container node for all crowd members in this block
var _people_container: Node3D

## List of all crowd members in this block
var _crowd_members: Array[CrowdPerson] = []

## Track camera for LOD calculations
var _camera: Camera3D


func _ready() -> void:
	if not config:
		push_error("CrowdBlock: No configuration resource assigned")
		return

	if not config.validate():
		push_error("CrowdBlock: Invalid configuration")
		return

	if not crowd_person_scene:
		push_error("CrowdBlock: No crowd_person_scene assigned")
		return

	_camera = get_viewport().get_camera_3d()

	_create_people_container()
	_generate_crowd_grid()
	_initialize_animations()


func _process(_delta: float) -> void:
	if config and config.lod_enabled and _camera:
		_update_lod_levels()


## Play random idle animation for a crowd member
func _play_random_idle_animation(person: CrowdPerson) -> void:
	if not person or not person.animation_state_machine:
		return

	if not person.play_idle_animation():
		push_warning("CrowdBlock: Failed to play idle animation for crowd member")
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
		_people_container.queue_free()


# Private methods

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
		push_error("CrowdBlock: Failed to instantiate crowd person")
		return null

	# Assign config and random model variant
	person.config = config
	person.model_key = config.get_random_model_variant()

	return person


func _initialize_animations() -> void:
	for person in _crowd_members:
		if person:
			_play_random_idle_animation(person)


func _update_lod_levels() -> void:
	if not _camera:
		return

	for person in _crowd_members:
		if not person:
			continue

		var distance = _camera.global_position.distance_to(person.global_position)
		var lod_level = config.get_lod_level(distance)

		if person.get_lod_level() != lod_level:
			person.set_lod_level(lod_level)
