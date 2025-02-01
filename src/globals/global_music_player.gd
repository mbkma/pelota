extends Node

signal song_started(song)

var music_queue: Array
var audio_stream_player: AudioStreamPlayer

func _ready() -> void:
	audio_stream_player = AudioStreamPlayer.new()
	add_child(audio_stream_player)
	audio_stream_player.finished.connect(on_audio_stream_player_finished)

func play(path: String):
	audio_stream_player.stream = load(path)
	audio_stream_player.play(0)
	emit_signal("song_started", path)

func stop():
	audio_stream_player.finished.disconnect(on_audio_stream_player_finished)
	audio_stream_player.stop()

func play_playlist(paths: Array):
	for p in paths:
		music_queue.push_back(p)
	play(music_queue[randi() % music_queue.size()])

func on_audio_stream_player_finished():
	if music_queue.size() == 0:
		return

	play(music_queue.pop_back())
