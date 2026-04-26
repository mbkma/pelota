class_name GlobalMusicPlayer
extends Node

signal track_started(track: Track)

@onready var music_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var sound_player: AudioStreamPlayer = AudioStreamPlayer.new()
var current_track: Track = null

@export var music: Array[Track]

var current_track_list: Array[Track] = []
var current_track_index: int = 0
var should_loop_playlist: bool = false
var is_shuffle_enabled: bool = false


func _ready():
	_setup_audio_player(music_player, "Music")
	music_player.finished.connect(_on_music_finished)
	_setup_audio_player(sound_player, "SFX")


func _setup_audio_player(player: AudioStreamPlayer, bus_name: String) -> void:
	player.stream = null
	player.bus = bus_name
	player.autoplay = false
	add_child(player)
	player.process_mode = Node.PROCESS_MODE_ALWAYS


func play_track_list(track_list: Array[Track], loop: bool = true, shuffle: bool = false) -> void:
	if track_list.is_empty():
		return

	current_track_list = track_list.duplicate()
	current_track_index = 0
	should_loop_playlist = loop
	is_shuffle_enabled = shuffle

	if shuffle:
		current_track_list.shuffle()

	_play_track_from_list(current_track_index, false)


func play_track(track: Track, loop: bool = true) -> void:
	# Clear playlist state when playing a single track
	current_track_list.clear()
	_play_track_internal(track, loop)


func play_sound(stream: AudioStream) -> void:
	sound_player.stream = stream
	sound_player.play()
	sound_player.stream_paused = false


func stop_music() -> void:
	music_player.stop()
	current_track = null
	current_track_list.clear()


func toggle_pause() -> void:
	music_player.stream_paused = !music_player.stream_paused


func _play_track_internal(track: Track, loop: bool = false) -> void:
	if current_track == track:
		return

	current_track = track
	music_player.stream = track.stream
	music_player.stream.loop = loop
	music_player.play()
	music_player.stream_paused = false
	track_started.emit(track)


func _play_track_from_list(index: int, should_loop: bool) -> void:
	if current_track_list.is_empty() or index >= current_track_list.size():
		return

	_play_track_internal(current_track_list[index], should_loop)


func _play_next_track() -> void:
	if current_track_list.is_empty():
		return

	current_track_index += 1

	if current_track_index >= current_track_list.size():
		if should_loop_playlist:
			current_track_index = 0
			if is_shuffle_enabled:
				current_track_list.shuffle()
		else:
			stop_music()
			return

	_play_track_from_list(current_track_index, false)


func _on_music_finished() -> void:
	if not current_track_list.is_empty():
		_play_next_track()
	elif music_player.stream and music_player.stream.loop:
		music_player.play()
