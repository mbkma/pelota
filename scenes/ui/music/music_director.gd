## Plays a random song when the game starts and the next random song whenever one ends,
## announcing each with the now-playing banner. Lives at the scene root so it keeps running
## across scene changes; matches and the training pause it and the menus resume it: the song
## goes on where it was paused.
class_name MusicDirector
extends CanvasLayer

const FADE_OUT_TIME: float = 1.5
const FADE_IN_TIME: float = 1.0

@export var playlist: MusicPlaylist

var _current_track: MusicTrack
var _stream_player: AudioStreamPlayer
## Volume (dB) the song plays at, faded back to when it resumes
var _volume_db: float = 0.0
## Fade of the music out or back in, null while none runs
var _fade: Tween
## Whether the music is stopped (fading out or paused) until resumed
var _stopped: bool = false

@onready var _banner: NowPlayingBanner = $NowPlayingBanner


func _ready() -> void:
	# The scene root is still adding this node; start playback once it is done.
	_play_next.call_deferred()


## The game quits (the director lives at the scene root until then): the song is let go, so
## that the music controller, leaving the tree after the director, does not copy it into itself
## as it leaves.
func _exit_tree() -> void:
	ProjectMusicController.music_stream_player = null


## Fades the paused song back in where it was paused; does nothing while music plays.
func resume() -> void:
	if not _stopped:
		return
	_stopped = false
	_kill_fade()
	_stream_player.stream_paused = false
	_fade = ProjectMusicController.blend_to(_volume_db, FADE_IN_TIME)


## Fades the music out and pauses it, e.g. when a match starts, and hides the banner.
func stop() -> void:
	if _stopped or not is_instance_valid(_stream_player):
		return
	_stopped = true
	_kill_fade()
	_fade = ProjectMusicController.fade_out(FADE_OUT_TIME)
	_fade.finished.connect(func() -> void: _stream_player.stream_paused = true)
	_banner.hide()


func _kill_fade() -> void:
	if _fade:
		_fade.kill()
		_fade = null


func _play_next() -> void:
	_current_track = playlist.pick_random(_current_track)
	_stream_player = ProjectMusicController.play_stream(_current_track.stream)
	_volume_db = _stream_player.volume_db
	_stream_player.finished.connect(_play_next, CONNECT_ONE_SHOT)
	_banner.announce(_current_track)
