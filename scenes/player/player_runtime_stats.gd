class_name PlayerRuntimeStats
extends Resource

@export var base_stats: PlayerStatsProfile
var mental_state: PlayerMentalState
var stamina_ratio: float = 1.0


func setup(stats_profile: PlayerStatsProfile, runtime_mental_state = null) -> void:
	base_stats = stats_profile
	mental_state = runtime_mental_state
	stamina_ratio = 1.0


func set_stamina_ratio(value: float) -> void:
	stamina_ratio = clampf(value, 0.0, 1.0)


func get_stamina_ratio() -> float:
	return stamina_ratio


func _base() -> PlayerStatsProfile:
	assert(base_stats != null, "PlayerRuntimeStats._base: base_stats is required")
	return base_stats


func value01(value: float) -> float:
	return _base().value01(value)


func stamina_capacity() -> float:
	return _base().stamina_capacity()


func stamina_preservation() -> float:
	var base_value: float = _base().stamina_preservation()
	var mental_bonus: float = mental_state.pressure_modifier() if mental_state else 0.5
	return clampf(base_value * lerpf(0.92, 1.08, mental_bonus), 0.0, 1.0)


func stamina_recovery_rate() -> float:
	var recovery: float = _base().stamina_recovery_rate()
	var mental_bonus: float = mental_state.confidence if mental_state else 0.5
	return recovery * lerpf(0.92, 1.08, mental_bonus)


func movement_speed_multiplier(stamina01: float) -> float:
	return _base().movement_speed_multiplier(stamina01)


func acceleration_multiplier(stamina01: float) -> float:
	return _base().acceleration_multiplier(stamina01)


func direction_change_resistance(stamina01: float) -> float:
	return _base().direction_change_resistance(stamina01)


func shot_side_skill01(is_backhand: bool) -> float:
	return _base().shot_side_skill01(is_backhand)


func shot_control01(stamina01: float) -> float:
	var control: float = _base().shot_control01(stamina01)
	var mental_bonus: float = mental_state.pressure_modifier() if mental_state and mental_state.has_method("pressure_modifier") else 0.5
	return clampf(control * lerpf(0.92, 1.06, mental_bonus), 0.0, 1.0)


func spin_control01(stroke_type: int, stamina01: float) -> float:
	return _base().spin_control01(stroke_type, stamina01)


func serve_power01() -> float:
	return _base().serve_power01()


func serve_accuracy01(stamina01: float) -> float:
	return _base().serve_accuracy01(stamina01)


func tactical_aggression01() -> float:
	var base_value: float = _base().tactical_aggression01()
	var mental_bonus: float = mental_state.aggression if mental_state else 0.5
	return clampf((base_value * 0.8) + (mental_bonus * 0.2), 0.0, 1.0)


func tactical_net_play01() -> float:
	return _base().tactical_net_play01()


func tactical_defense01() -> float:
	var base_value: float = _base().tactical_defense01()
	var mental_bonus: float = mental_state.discipline if mental_state else 0.5
	return clampf((base_value * 0.8) + (mental_bonus * 0.2), 0.0, 1.0)


func anticipation01() -> float:
	return _base().anticipation01()


func pressure_resistance01() -> float:
	var base_value: float = _base().pressure_resistance01()
	var mental_bonus: float = mental_state.pressure_modifier() if mental_state else 0.5
	return clampf((base_value * 0.7) + (mental_bonus * 0.3), 0.0, 1.0)