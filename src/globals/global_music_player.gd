extends Node

signal track_started(track: Track)

@onready var music_player: AudioStreamPlayer = AudioStreamPlayer.new()
var current_track: Track = null  # Stores the currently playing track

var music := [
	Track.new(
		"Hawaii",
		"Waesto",
		preload("res://assets/music/hawaii/Waesto - Hawaii.mp3"),
		"res://assets/music/md.webp"
	)
]


func _ready():
	# Add the AudioStreamPlayer node to the scene and make it persistent
	music_player.stream = null
	music_player.bus = "Music"  # Make sure to set up a Music bus in Audio settings
	music_player.autoplay = false
	add_child(music_player)
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS  # Ensures it runs even when scenes change


# Function to play music (only if it's not already playing)
func play_music(track: Track, loop: bool = true):
	if current_track == track:
		return  # Avoid restarting the same track
	current_track = track
	music_player.stream = track.stream
	music_player.play()
	music_player.stream_paused = false
	music_player.finished.connect(_on_music_finished)  # Ensure looping if needed
	music_player.stream.loop = loop
	track_started.emit(track)


# Function to stop music
func stop_music():
	music_player.stop()
	current_track = null


# Function to pause and resume music
func toggle_pause():
	music_player.stream_paused = !music_player.stream_paused


# Function to handle looping
func _on_music_finished():
	if music_player.stream and music_player.stream.loop:
		music_player.play()  # Restart if looping is enabled
