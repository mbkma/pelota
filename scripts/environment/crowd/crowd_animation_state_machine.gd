class_name CrowdAnimationStateMachine
extends Node

## Manages animation states and transitions for crowd members
## Provides a clean interface for playing idle and victory animations

enum AnimationState { IDLE, VICTORY, NONE }

var _animation_player: AnimationPlayer
var _current_state: AnimationState = AnimationState.NONE
var _config: CrowdConfig
var _blend_time: float = 0.5
var _animation_finished_callback: Callable
var _is_connected: bool = false
var _idle_animations: PackedStringArray = []
var _victory_animations: PackedStringArray = []

func _init(animation_player: AnimationPlayer, config: CrowdConfig) -> void:
	_animation_player = animation_player
	_config = config
	_blend_time = config.animation_blend_time
	_idle_animations = config.idle_animations
	_victory_animations = config.victory_animations

## Play a random idle animation with optional random offset
func play_idle_animation() -> bool:
	if _idle_animations.is_empty():
		return false

	var animation_name: String = _idle_animations[randi() % _idle_animations.size()]
	return play_animation(animation_name, AnimationState.IDLE, true)

## Play a random victory animation
func play_victory_animation() -> bool:
	if _victory_animations.is_empty():
		return false

	var animation_name: String = _victory_animations[randi() % _victory_animations.size()]
	return play_animation(animation_name, AnimationState.VICTORY, false)

## Play specific animation by name
func play_animation(animation_name: String, new_state: AnimationState, seek_random: bool = false) -> bool:
	if not _animation_player or not _animation_player.has_animation(animation_name):
		push_error("CrowdAnimationStateMachine: Animation '%s' not found" % animation_name)
		return false

	_current_state = new_state
	_animation_player.play(animation_name, _blend_time)

	if seek_random and _config.animation_seek_enabled:
		var animation_length: float = _animation_player.get_animation(animation_name).length
		_animation_player.seek(randf_range(0, animation_length), true)

	return true

## Setup idle animation looping
func setup_idle_loop() -> void:
	_disconnect_animation_finished()

	if _idle_animations.is_empty():
		return

	_animation_finished_callback = _on_animation_finished.bind(_idle_animations)
	_animation_player.animation_finished.connect(_animation_finished_callback)
	_is_connected = true

## Stop animation looping and disconnect signals
func stop_loop() -> void:
	_disconnect_animation_finished()
	_current_state = AnimationState.NONE

## Get current animation state
func get_state() -> AnimationState:
	return _current_state

## Get current animation name
func get_current_animation() -> String:
	if _animation_player and _animation_player.is_playing():
		return _animation_player.current_animation
	return ""

## Check if currently playing
func is_playing() -> bool:
	return _animation_player and _animation_player.is_playing()

## Cleanup resources
func cleanup() -> void:
	_disconnect_animation_finished()

# Private methods

func _on_animation_finished(_anim_name: StringName, animation_list: PackedStringArray) -> void:
	if animation_list.is_empty():
		return

	var new_animation: String = animation_list[randi() % animation_list.size()]
	play_animation(new_animation, _current_state, true)

func _disconnect_animation_finished() -> void:
	if _is_connected and _animation_player and _animation_finished_callback:
		_animation_player.animation_finished.disconnect(_animation_finished_callback)
		_is_connected = false
		_animation_finished_callback = Callable()
