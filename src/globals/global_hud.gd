extends Node

const music_panel = preload("res://src/hud/music_panel.tscn")
var canvas_layer: CanvasLayer


func _ready() -> void:
	canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	GlobalMusicPlayer.song_started.connect(on_song_started)


func on_song_started(song):
	# wait 3 sec after song has started to show the music panel
	await get_tree().create_timer(3).timeout
	var panel = music_panel.instantiate()
	panel.initialize(song)
	canvas_layer.add_child(panel)
