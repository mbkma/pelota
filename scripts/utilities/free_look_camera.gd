## Free-look camera for debugging and spectating (based on Marc Nahr's implementation)
## Copyright © 2022 Marc Nahr: https://github.com/MarcPhi/godot-free-look-camera
extends Camera3D

## Mouse sensitivity for rotation (0-10)
@export_range(0, 10, 0.01) var _sensitivity: float = 3

## Default movement velocity (0-1000 units/sec)
@export_range(0, 1000, 0.1) var _default_velocity: float = 5

## Speed scale multiplier for scrolling (1.17 = 17% per scroll)
@export_range(0, 10, 0.01) var _speed_scale: float = 1.17

## Boost speed multiplier when holding shift (1-100x)
@export_range(1, 100, 0.1) var _boost_speed_multiplier: float = 3.0

## Maximum movement velocity (units/sec)
@export var _max_speed: float = 1000.0

## Minimum movement velocity (units/sec)
@export var _min_speed: float = 0.2

## Current movement velocity (dynamically adjusted)
var _velocity: float


func _ready() -> void:
	_velocity = _default_velocity


## Handle mouse and keyboard input for camera control
func _input(event: InputEvent) -> void:
	if not current:
		return

	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			var mouse_event: InputEventMouseMotion = event as InputEventMouseMotion
			rotation.y -= mouse_event.relative.x / 1000.0 * _sensitivity
			rotation.x -= mouse_event.relative.y / 1000.0 * _sensitivity
			rotation.x = clamp(rotation.x, -PI / 2.0, PI / 2.0)

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		match mouse_button.button_index:
			MOUSE_BUTTON_RIGHT:
				Input.set_mouse_mode(
					Input.MOUSE_MODE_CAPTURED if mouse_button.pressed else Input.MOUSE_MODE_VISIBLE
				)
			MOUSE_BUTTON_WHEEL_UP:
				_velocity = clamp(_velocity * _speed_scale, _min_speed, _max_speed)
			MOUSE_BUTTON_WHEEL_DOWN:
				_velocity = clamp(_velocity / _speed_scale, _min_speed, _max_speed)


## Process camera movement based on WASD/QESD input
func _process(delta: float) -> void:
	if not current:
		return

	var direction: Vector3 = (
		Vector3(
			(
				float(Input.is_physical_key_pressed(KEY_D))
				- float(Input.is_physical_key_pressed(KEY_A))
			),
			(
				float(Input.is_physical_key_pressed(KEY_E))
				- float(Input.is_physical_key_pressed(KEY_Q))
			),
			(
				float(Input.is_physical_key_pressed(KEY_S))
				- float(Input.is_physical_key_pressed(KEY_W))
			)
		)
		. normalized()
	)

	# Apply boost multiplier if shift is held
	var speed_multiplier: float = (
		_boost_speed_multiplier if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0
	)
	translate(direction * _velocity * delta * speed_multiplier)
