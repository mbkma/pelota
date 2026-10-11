@tool
class_name Crowd
extends Node
## The crowd in the stands: its spectators, its sound and its reactions. It fills the stadium's
## seats with spectators, one block per section of seats (also in the editor), runs the clock
## they are animated by, plays an idle ambience and cheers after every point; the more exciting
## the point, the longer and louder the applause and the more spectators cheer.
## The idle sounds crossfade into each other, and the applause plays over them while they are
## turned down (the applause has its own crowd noise), so no sound is heard starting or ending.
## During the changeover after a set the crowd sounds like a changeover instead.

## Excitement from which the applause is medium and big instead of short
const MEDIUM_CHEER_EXCITEMENT: float = 0.35
const BIG_CHEER_EXCITEMENT: float = 0.7
## Cheer volume (dB) for the least and the most exciting point
const CHEER_VOLUME_DB_CALM: float = -4.0
const CHEER_VOLUME_DB_EXCITED: float = 0.0
## Seconds two idle sounds overlap while one fades into the next
const AMBIENCE_CROSSFADE: float = 3.0
## How far (dB) the idle sound is turned down under applause, and how long (s) turning it down
## and back up takes
const AMBIENCE_DUCK_DB: float = -6.0
const DUCK_DOWN_TIME: float = 0.4
const DUCK_UP_TIME: float = 2.0
## Seconds applause still playing fades out over when the next applause starts
const CHEER_FADE_OUT: float = 2.0
## Volume (dB) a fade-out ends at, and silent
const SILENT_DB: float = -60.0
## Share of spectators that cheer for the least and the most exciting point
const CHEER_SHARE_CALM: float = 0.15
const CHEER_SHARE_EXCITED: float = 1.0

@export var config: CrowdAudioConfig
## Seats of the stadium, and who sits on them
@export var seating: StadiumSeating
@export var spectators: CrowdConfig:
	set(value):
		if spectators and spectators.changed.is_connected(_seat_spectators):
			spectators.changed.disconnect(_seat_spectators)
		spectators = value
		if Engine.is_editor_hint() and spectators:
			spectators.changed.connect(_seat_spectators)
## Whether the crowd plays its idle ambience (off where other music plays, e.g. menus)
@export var play_ambience: bool = true

## Seconds of the crowd's clock
var _time: float = 0.0
## Materials of the spectators, which animate by the clock
var _materials: Array[ShaderMaterial] = []
var _blocks: Array[CrowdBlock] = []
var _photographers: CrowdBlock
## Which of the ambience players plays the current idle sound
var _ambience_current: int = 0
var _last_idle_sound: AudioStream
## Whether the players are at the changeover after a set
var _changeover: bool = false
## Number of idle sounds started so far; only the latest one schedules the next
var _idle_count: int = 0
## How far (0 to 1) the crossfade has moved from the previous idle sound to the current one
var _crossfade: float = 1.0
## Volume factor of the idle sounds, below 1 under applause
var _duck: float = 1.0
var _crossfade_tween: Tween
var _duck_tween: Tween
## Number of cheers so far; only the latest cheer turns the idle sound back up. The cheer players
## take turns, so that applause still playing can fade out under the next.
var _cheer_count: int = 0

@onready var _ambience_players: Array[AudioStreamPlayer] = [$AmbiencePlayer1, $AmbiencePlayer2]
@onready var _cheer_players: Array[AudioStreamPlayer] = [$CheerPlayer1, $CheerPlayer2]


func _ready() -> void:
	_seat_spectators()
	for character in spectators.characters:
		_materials.append(character.get_material())
	if Engine.is_editor_hint() or not play_ambience:
		return
	_play_next_idle_sound()


func _process(delta: float) -> void:
	_time += delta
	for material in _materials:
		material.set_shader_parameter(&"crowd_time", _time)


## Cheers after a point. `excitement` in [0, 1] sets the applause, its volume and how many
## spectators cheer.
func cheer(excitement: float) -> void:
	var sounds: Array[AudioStream] = config.short_cheers
	if excitement >= BIG_CHEER_EXCITEMENT:
		sounds = config.big_cheers
	elif excitement >= MEDIUM_CHEER_EXCITEMENT:
		sounds = config.medium_cheers
	var sound: AudioStream = sounds.pick_random()
	_cheer_count += 1
	var previous: AudioStreamPlayer = _cheer_players[(_cheer_count + 1) % 2]
	if previous.playing:
		var fade_out: Tween = create_tween()
		fade_out.tween_property(previous, "volume_db", SILENT_DB, CHEER_FADE_OUT)
		fade_out.tween_callback(previous.stop)
	var player: AudioStreamPlayer = _cheer_players[_cheer_count % 2]
	player.stream = sound
	player.volume_db = lerpf(CHEER_VOLUME_DB_CALM, CHEER_VOLUME_DB_EXCITED, excitement)
	player.play()
	if play_ambience:
		_duck_ambience(db_to_linear(AMBIENCE_DUCK_DB), DUCK_DOWN_TIME)
		var cheer_number: int = _cheer_count
		get_tree().create_timer(maxf(sound.get_length() - DUCK_UP_TIME, 0.0), false).timeout.connect(
			func() -> void:
				if cheer_number == _cheer_count:
					_duck_ambience(1.0, DUCK_UP_TIME)
		)
	var share: float = lerpf(CHEER_SHARE_CALM, CHEER_SHARE_EXCITED, excitement)
	for block in _blocks:
		block.cheer(share, _time)


func _seat_spectators() -> void:
	for block in _blocks:
		block.free()
	_blocks.clear()
	if _photographers:
		_photographers.free()
	for i in seating.sections.size():
		var block := CrowdBlock.new(spectators, seating.sections[i], spectators.occupancy, i)
		add_child(block)
		_blocks.append(block)
	# The photographers are all there, and do not cheer.
	_photographers = CrowdBlock.new(spectators, seating.photographers, 1.0, -1)
	add_child(_photographers)


## The players sit down for the changeover after a set: the crowd sounds like a changeover.
func start_changeover() -> void:
	_changeover = true
	if play_ambience:
		_play_next_idle_sound()


## The changeover is over: the crowd sounds as during play again.
func end_changeover() -> void:
	_changeover = false
	if play_ambience:
		_play_next_idle_sound()


## Starts another idle sound (not the one just played, apart from the changeover sound) on the
## other ambience player, crossfading into it from the current one, and the next one shortly
## before it ends.
func _play_next_idle_sound() -> void:
	var sound: AudioStream = config.changeover_sound
	if not _changeover:
		sound = config.idle_sounds.pick_random()
		while sound == _last_idle_sound and config.idle_sounds.size() > 1:
			sound = config.idle_sounds.pick_random()
	_last_idle_sound = sound
	_ambience_current = 1 - _ambience_current
	_ambience_players[_ambience_current].stream = sound
	_ambience_players[_ambience_current].play()
	_set_crossfade(0.0)
	if _crossfade_tween:
		_crossfade_tween.kill()
	_crossfade_tween = create_tween()
	_crossfade_tween.tween_method(_set_crossfade, 0.0, 1.0, AMBIENCE_CROSSFADE)
	_idle_count += 1
	var idle_number: int = _idle_count
	get_tree().create_timer(sound.get_length() - AMBIENCE_CROSSFADE, false).timeout.connect(
		func() -> void:
			if idle_number == _idle_count:
				_play_next_idle_sound()
	)


func _duck_ambience(target: float, duration: float) -> void:
	if _duck_tween:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_duck, _duck, target, duration)


func _set_crossfade(value: float) -> void:
	_crossfade = value
	_apply_ambience_volume()


func _set_duck(value: float) -> void:
	_duck = value
	_apply_ambience_volume()


## Equal-power crossfade: together the two idle sounds stay as loud as either alone.
func _apply_ambience_volume() -> void:
	var current: AudioStreamPlayer = _ambience_players[_ambience_current]
	var previous: AudioStreamPlayer = _ambience_players[1 - _ambience_current]
	current.volume_linear = sin(_crossfade * PI * 0.5) * _duck
	previous.volume_linear = cos(_crossfade * PI * 0.5) * _duck
