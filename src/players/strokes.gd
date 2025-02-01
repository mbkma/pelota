class_name Strokes
extends Node

@onready var sounds = $Sounds
@onready var sounds_flat: Array = sounds.get_node("Flat").get_children()
@onready var sounds_slice: Array = sounds.get_node("Slice").get_children()

var player
var standard_length := 10

func setup(player_) -> void:
	player = player_


func backhand_stop():
	return {"anim_id": player.skin.Strokes.BACKHAND, "pace": 10,  "to": Vector3(-sign(player.position.x)*3, 0, -sign(player.position.z)*4), "spin": -2, "height": 1.3}


func backhand_slice_cross():
	return {"anim_id": player.skin.Strokes.BACKHAND_SLICE, "pace": 20,  "to": Vector3(-sign(player.position.x)*3, 0, -sign(player.position.z)*standard_length), "spin": -5, "height": 1.3}


func backhand_slice_longline():
	return {"anim_id": player.skin.Strokes.BACKHAND_SLICE, "pace": 20,  "to": Vector3(sign(player.position.x)*3, 0, -sign(player.position.z)*standard_length), "spin": -5, "height": 1.3}


func backhand_cross():
	return {"anim_id": player.skin.Strokes.BACKHAND, "pace": player.stats.backhand_pace,  "to": Vector3(-sign(player.position.x)*3, 0, -sign(player.position.z)*standard_length), "spin": player.stats.backhand_spin, "height": 1 + player.stats.backhand_spin*0.1}


func backhand_longline():
	return {"anim_id": player.skin.Strokes.BACKHAND, "pace": player.stats.backhand_pace,  "to": Vector3(sign(player.position.x)*3, 0, -sign(player.position.z)*standard_length), "spin": player.stats.backhand_spin, "height": 1 + player.stats.backhand_spin*0.1}


func forehand_cross():
	return {"anim_id": player.skin.Strokes.FOREHAND, "pace": player.stats.forehand_pace,  "to": Vector3(-sign(player.position.x)*3, 0, -sign(player.position.z)*standard_length), "spin": player.stats.forehand_spin, "height": 1 + player.stats.forehand_spin*0.1}


func forehand_longline():
	return {"anim_id": player.skin.Strokes.FOREHAND, "pace": player.stats.forehand_pace,  "to": Vector3(sign(player.position.x)*3, 0, -sign(player.position.z)*standard_length), "spin": player.stats.forehand_spin, "height": 1 + player.stats.forehand_spin*0.1}


func serve_wide():
	return {"anim_id": player.skin.Strokes.SERVE, "pace": player.stats.serve_pace,  "to": Vector3(-sign(player.position.x)*3, 0, -sign(player.position.z)*5), "spin": 0, "height": 1.1}


func serve_body():
	return {"anim_id": player.skin.Strokes.SERVE, "pace": player.stats.serve_pace,  "to": Vector3(-sign(player.position.x)*3, 0, -sign(player.position.z)*5), "spin": 0, "height": 1.1}


func serve_t():
	return {"anim_id": player.skin.Strokes.SERVE, "pace": player.stats.serve_pace,  "to": Vector3(-sign(player.position.x)*1, 0, -sign(player.position.z)*5), "spin": 0, "height": 1.1}
