## Mental state of a player during a match: pressure from big points weighs on composure
## and confidence, won points restore them.
class_name PlayerMentalState
extends RefCounted

var composure: float
var clutch: float
var confidence: float = 0.5
var pressure: float = 0.0


## Starts the match with the player's mental traits; confidence and pressure start neutral.
func _init(profile: PlayerStatsProfile) -> void:
	composure = profile.value01(profile.composure)
	clutch = profile.value01(profile.clutch)


func apply_pressure(amount: float) -> void:
	pressure = clampf(pressure + amount, 0.0, 1.0)
	composure = clampf(composure - amount * 0.12, 0.0, 1.0)
	confidence = clampf(confidence - amount * 0.08, 0.0, 1.0)


func release_pressure(amount: float) -> void:
	pressure = clampf(pressure - amount, 0.0, 1.0)
	composure = clampf(composure + amount * 0.04, 0.0, 1.0)
	confidence = clampf(confidence + amount * 0.03, 0.0, 1.0)


func on_point_won() -> void:
	confidence = clampf(confidence + 0.05, 0.0, 1.0)
	pressure = clampf(pressure - 0.08, 0.0, 1.0)


func on_point_lost() -> void:
	pressure = clampf(pressure + 0.03, 0.0, 1.0)
	composure = clampf(composure - 0.03, 0.0, 1.0)


## How well the player copes with the current pressure, in [0, 1] (1 = unaffected).
## Composure and clutch absorb part of the pressure.
func pressure_modifier() -> float:
	var resilience: float = (composure * 0.55) + (clutch * 0.45)
	return clampf(1.0 - pressure * (1.0 - resilience * 0.8), 0.0, 1.0)
