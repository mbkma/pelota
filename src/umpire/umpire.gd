extends Node3D

var current_match: SinglesMatch


func setup_singles_match(sm: SinglesMatch) -> void:
	current_match = sm
	sm.match_data.match_score.points_changed.connect(_on_MatchScore_points_changed)
	sm.state_changed.connect(_on_MatchScore_state_changed)


func _on_MatchScore_state_changed(old_state, new_state):
	if (new_state == GlobalUtils.MatchStates.FAULT) and current_match.get_fault_reason() == "out":
		get_node("Sounds/out").play()
	elif new_state == GlobalUtils.MatchStates.SECOND_SERVE:
		get_node("Sounds/second_serve").play()


func _on_MatchScore_points_changed(score):
	var points = score.points
	if points[0] == 0 and points[1] == 0:
		return

	# say current score
	await get_tree().create_timer(1).timeout
	var str_points := str(points[0]) + "-" + str(points[1])
	var sound_effect := "Sounds/" + str_points
	if points[0] == 45 or points[1] == 45:
		sound_effect = "Sounds/advantage"

	var node = get_node(sound_effect)
	if node:
		node.play()
