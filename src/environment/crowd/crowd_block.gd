## Crowd block system that manages groups of spectator animations
extends Node3D

## Scene to instantiate for each crowd member
@export var _people: PackedScene = preload("res://src/environment/crowd/crowd_person.tscn")

## Number of rows of crowd members
@export var _rows: int = 10

## Number of columns of crowd members
@export var _columns: int = 4

## Horizontal spacing between crowd members (X axis)
@export var _seats_x: float = 0.7

## Vertical spacing between crowd rows (Y axis)
@export var _seats_y: float = 0.94 - 0.65

## Depth spacing between crowd rows (Z axis)
@export var _seats_z: float = 13.863 - 12.834

## Animation blend time for smooth transitions
var _blend_time: float = 0.5


func _ready() -> void:
	if not _people:
		return

	var seat_position: Vector3 = Vector3.ZERO
	for _row in range(_rows):
		for _col in range(_columns):
			var person: CrowdPerson = _people.instantiate()
			person.key = "crowd-" + str(randi_range(1, 4))
			person.position = seat_position
			add_child(person)

			_play_random_idle_animation(person)
			seat_position.x += _seats_x

		seat_position.x = 0.0
		seat_position.y += _seats_y
		seat_position.z -= _seats_z


## Play random idle animation for crowd member with random offset
func _play_random_idle_animation(person: CrowdPerson) -> void:
	if person.idle_animations.is_empty():
		return

	var animation_name: String = person.idle_animations[randi() % person.idle_animations.size()]

	# Only play if animation exists
	if not person.animation_player.has_animation(animation_name):
		return

	# Play animation with smooth blending
	person.animation_player.play(animation_name, _blend_time)

	# Offset animation randomly to vary the crowd
	var animation_length: float = person.animation_player.get_animation(animation_name).length
	person.animation_player.seek(randf_range(0, animation_length), true)

	# Loop through idle animations smoothly
	person.animation_player.animation_finished.connect(
		func _on_animation_finished(_anim_name: StringName) -> void:
			if person.idle_animations.is_empty():
				return
			var new_animation: String = person.idle_animations[
				randi() % person.idle_animations.size()
			]
			person.animation_player.play(new_animation, _blend_time)
	)


## Play victory celebration animations for all crowd members
func play_victory() -> void:
	for child in get_children():
		if child is CrowdPerson:
			var person: CrowdPerson = child as CrowdPerson
			if person.victory_animations.is_empty():
				continue

			var animation_name: String = person.victory_animations[
				randi() % person.victory_animations.size()
			]

			if not person.animation_player.has_animation(animation_name):
				continue

			person.animation_player.play(animation_name, _blend_time)
			var animation_length: float = (
				person.animation_player.get_animation(animation_name).length
			)
			person.animation_player.seek(randf_range(0, animation_length), true)
