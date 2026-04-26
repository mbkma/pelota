## Abstract base class for input device handling
## Subclasses implement specific input methods (keyboard, mouse, gamepad, etc)
@abstract
class_name InputDevice
extends Node

enum StrokeInputType {
	TOPSPIN,
	SLICE,
	DROP_SHOT,
}

## Signal emitted when stroke button is first pressed
signal stroke_started

## Signal emitted while stroke button is held
signal stroke_updating(pace: float, stroke_type: StrokeInputType)

## Signal emitted when stroke button is released
signal stroke_completed(pace: float, stroke_type: StrokeInputType)


func emit_stroke_started() -> void:
	stroke_started.emit()


func emit_stroke_updating(pace: float, stroke_type: StrokeInputType) -> void:
	stroke_updating.emit(pace, stroke_type)


func emit_stroke_completed(pace: float, stroke_type: StrokeInputType) -> void:
	stroke_completed.emit(pace, stroke_type)

@abstract
func initialize(index: int) -> void

## Called once per physics frame to get movement input direction
@abstract
func get_movement_input(_player_basis: Basis, _player_position: Vector3) -> Vector3

## Called once per physics frame to get movement input direction
@abstract
func get_aim_input() -> Vector3

## Called once per frame to handle stroke input (returns true if any stroke action is active)
@abstract
func handle_stroke_input() -> bool

## Returns the current stroke pace (0.0 to 1.0)
@abstract
func get_stroke_pace() -> float

## Returns the current stroke input type
@abstract
func get_stroke_type() -> StrokeInputType

## Clears input state (called after stroke execution)
func clear_stroke_input() -> void:
	pass

## Sets serve mode (disables movement, allows only aiming)
func set_serve_mode(_enabled: bool) -> void:
	pass
