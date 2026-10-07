class_name Crowd
extends Node
## Crowd sound and reactions. Plays an idle ambience and cheers after every point; the more
## exciting the point, the louder the cheer and the more spectators get up.

## Cheer volume (dB) for the least and the most exciting point
const CHEER_VOLUME_DB_CALM: float = -15.0
const CHEER_VOLUME_DB_EXCITED: float = 0.0
## Share of spectators that cheer for the least and the most exciting point
const CHEER_SHARE_CALM: float = 0.15
const CHEER_SHARE_EXCITED: float = 1.0

@export var config: CrowdAudioConfig
## Whether the crowd plays its idle ambience (off where other music plays, e.g. menus)
@export var play_ambience: bool = true

@onready var _audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer


func _ready() -> void:
	if not play_ambience:
		return
	_audio_stream_player.finished.connect(play_idle_sound)
	play_idle_sound()


## Plays an idle crowd sound; another one follows when it (or a cheer) ends.
func play_idle_sound() -> void:
	_play_sound(config.idle_sounds.pick_random(), 0.0)


## Cheers after a point. `excitement` in [0, 1] sets the volume and how many spectators cheer.
func cheer(excitement: float) -> void:
	_play_sound(
		config.after_point_sounds.pick_random(),
		lerpf(CHEER_VOLUME_DB_CALM, CHEER_VOLUME_DB_EXCITED, excitement)
	)
	var share: float = lerpf(CHEER_SHARE_CALM, CHEER_SHARE_EXCITED, excitement)
	for stand in get_children():
		for crowd_block in stand.get_children():
			if crowd_block is CrowdBlock:
				crowd_block.cheer(share)


func _play_sound(stream: AudioStream, volume_db: float) -> void:
	_audio_stream_player.stream = stream
	_audio_stream_player.volume_db = volume_db
	_audio_stream_player.play()
