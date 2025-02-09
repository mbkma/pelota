extends Node

@onready var sounds: Node = $Sounds
@onready var cheer_after_point_sounds: Array = sounds.get_node("CheerAfterPoint").get_children()
@onready var idle_sounds: Array = sounds.get_node("Idle").get_children()

var current_sound_index := 0

#
#func setup_singles_match(sm: SinglesMatch) -> void:
	#sm.match_data.match_score.points_changed.connect(_on_MatchScore_points_changed)
	#sm.state_changed.connect(_on_SinglesMatch_state_changed)
	#idle_sounds[current_sound_index].play()
#
#
#func _on_MatchScore_points_changed(score: MatchScore) -> void:
	#cheer_after_point_sounds[randi() % cheer_after_point_sounds.size()].play()
#
#
#func _on_SinglesMatch_state_changed(old_state, new_state) -> void:
	#current_sound_index = randi() % idle_sounds.size()
	#if new_state == GlobalUtils.MatchStates.IDLE:
		#idle_sounds[current_sound_index].volume_db -= 5
		#idle_sounds[current_sound_index].play()
	#elif new_state == GlobalUtils.MatchStates.SERVE:
		#idle_sounds[current_sound_index].volume_db -= 15
