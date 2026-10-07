## Plays a random song when the game starts and the next random song whenever one ends,
## announcing each with the now-playing banner. Lives at the scene root so it keeps running
## across scene changes; matches stop it and the main menu resumes it.
class_name MusicDirector
extends CanvasLayer

const FADE_OUT_TIME: float = 1.5

@export var playlist: MusicPlaylist

var _current_track: MusicTrack
var _stream_player: AudioStreamPlayer

@onready var _banner: NowPlayingBanner = $NowPlayingBanner


func _ready() -> void:
	# The scene root is still adding this node; start playback once it is done.
	_play_next.call_deferred()


## Starts a new random song unless music is already playing.
func resume() -> void:
	if not is_instance_valid(_stream_player):
		_play_next()


## Fades the music out and hides the banner, e.g. when a match starts.
func stop() -> void:
	if not is_instance_valid(_stream_player):
		return
	_stream_player.finished.disconnect(_play_next)
	_stream_player = null
	ProjectMusicController.fade_out(FADE_OUT_TIME).finished.connect(ProjectMusicController.stop)
	_banner.hide()


func _play_next() -> void:
	_current_track = playlist.pick_random(_current_track)
	_stream_player = ProjectMusicController.play_stream(_current_track.stream)
	_stream_player.finished.connect(_play_next, CONNECT_ONE_SHOT)
	_banner.announce(_current_track)
