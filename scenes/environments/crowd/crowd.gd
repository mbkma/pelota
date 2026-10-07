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

## Containers of the crowd blocks
@export var blocks: Array[Node3D]

@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer


func _ready() -> void:
	if not play_ambience:
		return
	audio_stream_player.finished.connect(play_idle_sound)
	play_idle_sound()


## Plays an idle crowd sound; another one follows when it (or a cheer) ends.
func play_idle_sound() -> void:
	_play_sound(config.get_random_idle_sound(), 0.0)


## Cheers after a point. `excitement` in [0, 1] sets the volume and how many spectators cheer.
func cheer(excitement: float) -> void:
	_play_sound(
		config.get_random_after_point_sound(),
		lerpf(CHEER_VOLUME_DB_CALM, CHEER_VOLUME_DB_EXCITED, excitement)
	)
	var share: float = lerpf(CHEER_SHARE_CALM, CHEER_SHARE_EXCITED, excitement)
	for block in blocks:
		for crowd_block in block.get_children():
			if crowd_block is CrowdBlock:
				(crowd_block as CrowdBlock).cheer(share)


func _play_sound(stream: AudioStream, volume_db: float) -> void:
	audio_stream_player.stream = stream
	audio_stream_player.volume_db = volume_db
	audio_stream_player.play()
