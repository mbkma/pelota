extends Node


func _ready() -> void:
	var p: Player = load("res://scenes/player/player.tscn").instantiate()
	p.player_data = GlobalGameData.get_ranked_players()[0]
	GlobalGameData.set_match_input_devices(InputDevice.NO_DEVICE_ID, InputDevice.NO_DEVICE_ID)
	add_child(p)
	await get_tree().process_frame
	var model: Model = p.model
	var sk: Skeleton3D = model._skeleton
	var bone: int = sk.find_bone(Model.RACKET_GRIP_BONE)
	var lib := model.animator
	for n in ["backhand_slice", "backhand", "backhand_down", "backhand_up", "forehand", "forehand_down", "forehand_up"]:
		var a: Animation = lib.get_animation(n)
		var start: Vector3 = ClipPose.blended_bone_pose(a, 0.0, a, 0.0, 0.0, sk, bone).origin
		var line := "%-15s swing=%.2f hit=%.2f |" % [n, a.get_marker_time(&"swing"), a.get_marker_time(&"hit")]
		var t := 0.0
		var prev: Vector3 = start
		while t <= a.get_marker_time(&"hit") + 0.001:
			var pos: Vector3 = ClipPose.blended_bone_pose(a, t, a, t, 0.0, sk, bone).origin
			line += " %.2f:%2d" % [t, roundi(pos.distance_to(start) * 100)]
			prev = pos
			t += 0.1
		print(line)
	get_tree().quit()
