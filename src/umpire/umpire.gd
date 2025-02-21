class_name Umpire
extends Node3D

@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

@export var umpire_sounds := {
	"0-1": preload("res://src/umpire/sounds/0-15.ogg"),
	"0-2": preload("res://src/umpire/sounds/0-30.ogg"),
	"0-3": preload("res://src/umpire/sounds/0-40.ogg"),
	"1-0": preload("res://src/umpire/sounds/15-0.ogg"),
	"1-1": preload("res://src/umpire/sounds/15-15.ogg"),
	"1-2": preload("res://src/umpire/sounds/15-30.ogg"),
	"1-3": preload("res://src/umpire/sounds/15-40.ogg"),
	"2-0": preload("res://src/umpire/sounds/30-0.ogg"),
	"2-1": preload("res://src/umpire/sounds/30-15.ogg"),
	"2-2": preload("res://src/umpire/sounds/30-30.ogg"),
	"2-3": preload("res://src/umpire/sounds/30-40.ogg"),
	"3-0": preload("res://src/umpire/sounds/40-0.ogg"),
	"3-1": preload("res://src/umpire/sounds/40-15.ogg"),
	"3-2": preload("res://src/umpire/sounds/40-30.ogg"),
	"3-3": preload("res://src/umpire/sounds/40-40.ogg"),
	"advantage": preload("res://src/umpire/sounds/advantage.ogg"),
	"out": preload("res://src/umpire/sounds/out.wav"),
	"second_serve": preload("res://src/umpire/sounds/second_serve.ogg"),
}


func say_second_serve():
	audio_stream_player.stream = umpire_sounds["second_serve"]
	audio_stream_player.play()


func say_fault():
	audio_stream_player.stream = umpire_sounds["out"]
	audio_stream_player.play()


func say_score(score: Score):
	var points = score.points
	if points[0] == score.TennisPoint.LOVE and points[1] == score.TennisPoint.LOVE:
		return

	# say current score
	await get_tree().create_timer(1).timeout
	var key := str(points[0]) + "-" + str(points[1])
	var stream = umpire_sounds[key]
	if points[0] == score.TennisPoint.AD or points[1] == score.TennisPoint.AD:
		stream = umpire_sounds["advantage"]

	audio_stream_player.stream = stream
	audio_stream_player.play()
