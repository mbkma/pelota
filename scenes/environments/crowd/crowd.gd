@tool
class_name Crowd
extends Node
## The crowd in the stands: its blocks of spectators, its sound and its reactions. It runs the
## clock the spectators are animated by (also in the editor), plays an idle ambience and cheers
## after every point; the more exciting the point, the louder the cheer and the more spectators
## cheer.

## Cheer volume (dB) for the least and the most exciting point
const CHEER_VOLUME_DB_CALM: float = -15.0
const CHEER_VOLUME_DB_EXCITED: float = 0.0
## Share of spectators that cheer for the least and the most exciting point
const CHEER_SHARE_CALM: float = 0.15
const CHEER_SHARE_EXCITED: float = 1.0

@export var config: CrowdAudioConfig
## Whether the crowd plays its idle ambience (off where other music plays, e.g. menus)
@export var play_ambience: bool = true

## Seconds of the crowd's clock
var _time: float = 0.0
## Materials of the spectators, which animate by the clock
var _materials: Array[ShaderMaterial] = []

@onready var _audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer


func _ready() -> void:
	for block in _blocks():
		for character in block.config.characters:
			if not _materials.has(character.get_material()):
				_materials.append(character.get_material())
	if Engine.is_editor_hint() or not play_ambience:
		return
	_audio_stream_player.finished.connect(play_idle_sound)
	play_idle_sound()


func _process(delta: float) -> void:
	_time += delta
	for material in _materials:
		material.set_shader_parameter(&"crowd_time", _time)


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
	for block in _blocks():
		block.cheer(share, _time)


func _blocks() -> Array[CrowdBlock]:
	var blocks: Array[CrowdBlock] = []
	for stand in get_children():
		for child in stand.get_children():
			if child is CrowdBlock:
				blocks.append(child)
	return blocks


func _play_sound(stream: AudioStream, volume_db: float) -> void:
	_audio_stream_player.stream = stream
	_audio_stream_player.volume_db = volume_db
	_audio_stream_player.play()
