class_name PlayerMentalState
extends Resource

@export_range(0.0, 1.0, 0.01) var composure: float = 0.5
@export_range(0.0, 1.0, 0.01) var confidence: float = 0.5
@export_range(0.0, 1.0, 0.01) var aggression: float = 0.5
@export_range(0.0, 1.0, 0.01) var discipline: float = 0.5
@export_range(0.0, 1.0, 0.01) var adaptability: float = 0.5
@export_range(0.0, 1.0, 0.01) var clutch: float = 0.5
@export_range(0.0, 1.0, 0.01) var pressure: float = 0.0


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
	pressure = clampf(pressure + 0.08, 0.0, 1.0)
	composure = clampf(composure - 0.03, 0.0, 1.0)


func pressure_modifier() -> float:
	return clampf((composure * 0.55) + (clutch * 0.45) - pressure * 0.25, 0.0, 1.0)