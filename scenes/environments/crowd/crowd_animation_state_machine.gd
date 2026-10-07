class_name CrowdAnimationStateMachine
extends RefCounted
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
	_animation_player.animation_finished.connect(start_idle.unbind(1))


## Plays a random idle animation, or holds a random idle pose for spectators that are not
## animated.
func start_idle() -> void:
	var animation_name: String = _config.idle_animations[randi() % _config.idle_animations.size()]
	_animation_player.play(animation_name, _config.animation_blend_time)
	if _config.animation_seek_enabled:
		var length: float = _animation_player.get_animation(animation_name).length
		_animation_player.seek(randf_range(0.0, length), true)
	if not _animated:
		_animation_player.pause()


## Plays a random victory animation, then returns to idle.
func play_victory_animation() -> void:
	var victory_animations: PackedStringArray = _config.victory_animations
	_animation_player.play(
		victory_animations[randi() % victory_animations.size()], _config.animation_blend_time
	)
