## The electronic line calling's light bars at the two ends of the net: dark while play goes on,
## they flash red when a ball is called out (a "Fault"), as on the net posts at the US Open.
## The bars, their material and their AreaLight3Ds (one on each face, lighting the court on both
## sides of the net) are set up in court.tscn, dark: the lights are hidden and their energy set
## there is the lit one.
class_name NetLedBars
extends Node3D

## The bars' shared material, its emission dark until a fault
@export var bar_material: StandardMaterial3D
## Emission (brightness) of a lit bar: it glows in the camera's bloom
@export var lit_emission: float = 2.2
## Seconds the bars light up, stay lit and fade out
@export var light_up_time: float = 0.06
@export var lit_time: float = 4.2
@export var fade_time: float = 0.6

## The bars' area lights and the energy each has when lit
var _lights: Array[AreaLight3D] = []
var _lit_light_energies: Array[float] = []
var _brightness: float = 0.0
var _tween: Tween


func _ready() -> void:
	for light: Node in find_children("*", "AreaLight3D"):
		_lights.append(light)
		_lit_light_energies.append(light.light_energy)
	_set_brightness(0.0)


## Lights the bars red for a moment: a ball was called out.
func flash_fault() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_brightness, _brightness, 1.0, light_up_time)
	_tween.tween_interval(lit_time)
	_tween.tween_method(_set_brightness, 1.0, 0.0, fade_time)


## Fades the bars out if still lit: play goes on.
func turn_off() -> void:
	if _brightness == 0.0:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_brightness, _brightness, 0.0, fade_time)


## Sets the bars' glow and lights between dark (0) and lit (1); dark lights are hidden, as area
## lights cost GPU time on everything in view.
func _set_brightness(brightness: float) -> void:
	_brightness = brightness
	bar_material.emission_energy_multiplier = lit_emission * brightness
	for i: int in _lights.size():
		_lights[i].light_energy = _lit_light_energies[i] * brightness
		_lights[i].visible = brightness > 0.0
