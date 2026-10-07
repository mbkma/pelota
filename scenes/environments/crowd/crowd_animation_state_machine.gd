@tool
class_name CrowdAnimationStateMachine
extends Node

## Animates one spectator. Animated spectators (a share set by
## CrowdConfig.animation_percentage) loop random idle animations; the others hold a still,
## random idle pose, which costs nothing per frame and keeps large crowds cheap. Everybody
## cheers on play_victory_animation and returns to idle afterwards.

var _animation_player: AnimationPlayer
var _config: CrowdConfig
var _animated: bool


func _init(animation_player: AnimationPlayer, config: CrowdConfig) -> void:
	_animation_player = animation_player
	_config = config
	_animated = randf() < config.animation_percentage
	_animation_player.animation_finished.connect(_on_animation_finished)


## Plays a random idle animation, or holds a random idle pose for spectators that are not
## animated.
func start_idle() -> void:
	_play(_config.get_random_idle_animation(), true)
	if not _animated:
		_animation_player.pause()


## Plays a random victory animation, then returns to idle.
func play_victory_animation() -> void:
	_play(_config.get_random_victory_animation(), false)


func cleanup() -> void:
	if _animation_player.animation_finished.is_connected(_on_animation_finished):
		_animation_player.animation_finished.disconnect(_on_animation_finished)


func _play(animation_name: String, seek_random: bool) -> void:
	_animation_player.play(animation_name, _config.animation_blend_time)
	if seek_random and _config.animation_seek_enabled:
		var animation_length: float = _animation_player.get_animation(animation_name).length
		_animation_player.seek(randf_range(0.0, animation_length), true)


func _on_animation_finished(_animation_name: StringName) -> void:
	start_idle()
