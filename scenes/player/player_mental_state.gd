class_name PlayerMentalState
extends Resource

@export_range(0.0, 1.0, 0.01) var composure: float = 0.5
@export_range(0.0, 1.0, 0.01) var confidence: float = 0.5
@export_range(0.0, 1.0, 0.01) var aggression: float = 0.5
@export_range(0.0, 1.0, 0.01) var discipline: float = 0.5
@export_range(0.0, 1.0, 0.01) var adaptability: float = 0.5
@export_range(0.0, 1.0, 0.01) var clutch: float = 0.5
@export_range(0.0, 1.0, 0.01) var pressure: float = 0.0


## Starts the match with the player's mental traits; confidence and pressure start neutral.
func setup(profile: PlayerStatsProfile) -> void:
	composure = profile.value01(profile.composure)
	clutch = profile.value01(profile.clutch)
	aggression = profile.value01(profile.aggression)
	discipline = profile.value01(profile.consistency)
	adaptability = profile.value01(profile.focus)
	confidence = 0.5
	pressure = 0.0


func apply_pressure(amount: float) -> void:
	pressure = clampf(pressure + maxf(amount, 0.0), 0.0, 1.0)
	composure = clampf(composure - amount * 0.12, 0.0, 1.0)
	confidence = clampf(confidence - amount * 0.08, 0.0, 1.0)


func release_pressure(amount: float) -> void:
	pressure = clampf(pressure - maxf(amount, 0.0), 0.0, 1.0)
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