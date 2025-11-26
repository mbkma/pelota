## Abstract base class for input device handling
## Subclasses implement specific input methods (keyboard, mouse, gamepad, etc)
@abstract
class_name InputDevice
extends Node

## Signal emitted when stroke button is first pressed
signal stroke_started

## Signal emitted while stroke button is held
signal stroke_updating(pace: float)

## Signal emitted when stroke button is released
signal stroke_completed(pace: float, stroke_type: String)

## Called once per physics frame to get movement input direction
@abstract
func get_movement_input(_camera_basis: Basis, _player_position: Vector3) -> Vector3

## Called once per frame to get aiming input
@abstract
func get_aiming_input() -> Vector2

## Called once per frame to handle stroke input (returns true if any stroke action is active)
@abstract
func handle_stroke_input() -> bool

## Returns the current stroke pace (0.0 to 1.0)
@abstract
func get_stroke_pace() -> float

## Returns the current stroke type ("topspin", "slice", "drop_shot")
@abstract
func get_stroke_type() -> String

## Returns the current aiming position in 3D space
@abstract
func get_aiming_position() -> Vector3

## Returns true if challenge action was just pressed
func is_challenge_pressed() -> bool:
	return Input.is_action_just_pressed("challenge")

## Clears input state (called after stroke execution)
func clear_stroke_input() -> void:
	pass

## Sets serve mode (disables movement, allows only aiming)
func set_serve_mode(_enabled: bool) -> void:
	pass
