class_name PlayerStatsProfile
extends Resource

# Core physical (0-100)
@export_range(1.0, 100.0, 1.0) var acceleration: float = 70.0
@export_range(1.0, 100.0, 1.0) var top_speed: float = 70.0
@export_range(1.0, 100.0, 1.0) var agility: float = 70.0
@export_range(1.0, 100.0, 1.0) var stamina: float = 75.0

# Shot quality (0-100)
@export_range(1.0, 100.0, 1.0) var forehand: float = 70.0
@export_range(1.0, 100.0, 1.0) var backhand: float = 70.0
@export_range(1.0, 100.0, 1.0) var serve_power: float = 70.0
@export_range(1.0, 100.0, 1.0) var serve_accuracy: float = 70.0
@export_range(1.0, 100.0, 1.0) var return_skill: float = 70.0
@export_range(1.0, 100.0, 1.0) var volley_skill: float = 65.0
@export_range(1.0, 100.0, 1.0) var slice_skill: float = 65.0
@export_range(1.0, 100.0, 1.0) var topspin_skill: float = 65.0

# Precision / consistency (0-100)
@export_range(1.0, 100.0, 1.0) var accuracy: float = 72.0
@export_range(1.0, 100.0, 1.0) var consistency: float = 72.0
@export_range(1.0, 100.0, 1.0) var timing: float = 70.0

# Mental (0-100)
@export_range(1.0, 100.0, 1.0) var composure: float = 70.0
@export_range(1.0, 100.0, 1.0) var focus: float = 70.0
@export_range(1.0, 100.0, 1.0) var clutch: float = 70.0

# Tactical / style (0-100)
@export_range(1.0, 100.0, 1.0) var aggression: float = 68.0
@export_range(1.0, 100.0, 1.0) var net_play: float = 60.0
@export_range(1.0, 100.0, 1.0) var defensive_skill: float = 70.0
@export_range(1.0, 100.0, 1.0) var shot_anticipation: float = 70.0

# Surface affinity (0-100)
@export_range(1.0, 100.0, 1.0) var clay_skill: float = 70.0
@export_range(1.0, 100.0, 1.0) var grass_skill: float = 70.0
@export_range(1.0, 100.0, 1.0) var hard_court_skill: float = 70.0


func value01(value: float) -> float:
	return clampf(value / 100.0, 0.0, 1.0)


func stamina_capacity() -> float:
	# Stamina drives the size of the energy pool for match-long degradation.
	return lerpf(72.0, 165.0, value01(stamina))


func stamina_preservation() -> float:
	# Focus and composure slow down fatigue accumulation.
	return clampf((value01(focus) * 0.65) + (value01(composure) * 0.35), 0.0, 1.0)


func stamina_recovery_rate() -> float:
	var baseline: float = lerpf(3.5, 9.0, value01(stamina))
	return baseline * lerpf(0.8, 1.25, value01(focus))


func movement_speed_multiplier(stamina01: float) -> float:
	var speed_skill: float = value01(top_speed)
	var fatigue_penalty: float = lerpf(0.82, 1.0, stamina01)
	return lerpf(0.85, 1.2, speed_skill) * fatigue_penalty


func acceleration_multiplier(stamina01: float) -> float:
	var accel_skill: float = value01(acceleration)
	var agility_skill: float = value01(agility)
	var fatigue_penalty: float = lerpf(0.76, 1.0, stamina01)
	return lerpf(0.8, 1.2, accel_skill) * lerpf(0.9, 1.15, agility_skill) * fatigue_penalty


func direction_change_resistance(stamina01: float) -> float:
	# Lower values lose less speed on pivots.
	var agility_skill: float = value01(agility)
	var fatigue_penalty: float = lerpf(1.08, 1.0, stamina01)
	return lerpf(0.42, 0.12, agility_skill) * fatigue_penalty


func shot_side_skill01(is_backhand: bool) -> float:
	return value01(backhand) if is_backhand else value01(forehand)


func shot_control01(stamina01: float) -> float:
	var base_control: float = (
		value01(accuracy) * 0.35 +
		value01(consistency) * 0.35 +
		value01(timing) * 0.20 +
		value01(composure) * 0.10
	)
	var fatigue_penalty: float = lerpf(0.72, 1.0, stamina01)
	return clampf(base_control * fatigue_penalty, 0.0, 1.0)


func spin_control01(stroke_type: int, stamina01: float) -> float:
	var topspin_weight: float = value01(topspin_skill)
	var slice_weight: float = value01(slice_skill)
	var stroke_spin_skill: float = topspin_weight
	if stroke_type == Stroke.StrokeType.BACKHAND_SLICE:
		stroke_spin_skill = slice_weight
	if stroke_type == Stroke.StrokeType.FOREHAND_DROP_SHOT or stroke_type == Stroke.StrokeType.BACKHAND_DROP_SHOT:
		stroke_spin_skill = (slice_weight + topspin_weight) * 0.5

	var fatigue_penalty: float = lerpf(0.75, 1.0, stamina01)
	return clampf(stroke_spin_skill * fatigue_penalty, 0.0, 1.0)


func serve_power01() -> float:
	return value01(serve_power)


func serve_accuracy01(stamina01: float) -> float:
	var composure_mix: float = (value01(serve_accuracy) * 0.75) + (value01(composure) * 0.25)
	var fatigue_penalty: float = lerpf(0.78, 1.0, stamina01)
	return clampf(composure_mix * fatigue_penalty, 0.0, 1.0)


func tactical_aggression01() -> float:
	return clampf(value01(aggression), 0.0, 1.0)


func tactical_net_play01() -> float:
	return clampf(value01(net_play), 0.0, 1.0)


func tactical_defense01() -> float:
	return clampf(value01(defensive_skill), 0.0, 1.0)


func anticipation01() -> float:
	return clampf(value01(shot_anticipation), 0.0, 1.0)


func pressure_resistance01() -> float:
	return clampf((value01(composure) * 0.6) + (value01(clutch) * 0.4), 0.0, 1.0)
