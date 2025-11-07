## Base class for player input handling (human/AI)
## Defines the interface that all input methods must implement
class_name InputMethod
extends Node

## Reference to parent player this input handler controls
var player: Player

## Signal emitted when aiming position changes
signal aiming_at_position(position: Vector3)

## Signal emitted when pace/power changes
signal pace_changed(pace: float)

## Signal emitted when input method changes timing
signal input_changed(timing: float)


## Initialize input method (called when scene ready)
func _ready() -> void:
	if not player:
		player = get_parent()
		if not player or not player is Player:
			push_error("InputMethod parent must be a Player node, got: ", get_parent().name)


## Process input each frame for state updates
func _process(_delta: float) -> void:
	pass


## Process physics-related input (movement)
func _physics_process(_delta: float) -> void:
	pass


## Request the input method to initiate a serve
## Implementing classes should handle serve initialization here
func request_serve() -> void:
	push_error("request_serve() not implemented in: ", get_class())


## Validate player reference and state
## Returns true if valid, false otherwise
func validate_player() -> bool:
	if not player:
		push_error("InputMethod has no player reference")
		return false
	if not player is Player:
		push_error("InputMethod player is not a Player instance: ", player.name)
		return false
	return true
