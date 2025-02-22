extends Node3D

@export var people := preload("res://src/crowd/crowd_person.tscn")

@export var rows := 10
@export var columns := 4
@export var seats_x := 0.7
@export var seats_y := 0.94 - 0.65
@export var seats_z := 13.863 - 12.834


func _ready():
	var seat_position := Vector3.ZERO
	for i in range(rows):  # Create 50 people
		for j in range(columns):
			var person = people.instantiate()
			person.key = "crowd-" + str(randi_range(1, 4))
			person.position = seat_position
			add_child(person)

			# Pick a random idle animation
			var animation_name = person.idle_animations[randi() % person.idle_animations.size()]

			# Play the animation with blending
			var blend_time = 0.5  # Adjust for smoother transitions
			person.animation_player.play(animation_name, blend_time)

			# Offset animation randomly
			var animation_length = person.animation_player.get_animation(animation_name).length
			person.animation_player.seek(randf_range(0, animation_length), true)

			# Loop through animations smoothly
			person.animation_player.animation_finished.connect(
				func _on_animation_finished(anim_name):
					var new_animation = person.idle_animations[
						randi() % person.idle_animations.size()
					]
					person.animation_player.play(new_animation, blend_time)
			)
			seat_position.x += seats_x

		seat_position.x = 0.0
		seat_position.y += seats_y
		seat_position.z -= seats_z


func play_victory():
	for person in get_children():
		var animation_name = person.victory_animations[randi() % person.victory_animations.size()]
		# Play the animation with blending
		var blend_time = 0.5  # Adjust for smoother transitions
		person.animation_player.play(animation_name, blend_time)
		var animation_length = person.animation_player.get_animation(animation_name).length

		person.animation_player.seek(randf_range(0, animation_length), true)
