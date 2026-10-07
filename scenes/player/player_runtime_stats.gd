## The player's stat profile as it plays out in the match: pressure lowers precision, and
## confidence speeds up recovery.
class_name PlayerRuntimeStats
extends RefCounted

var _base: PlayerStatsProfile
var _mental_state: PlayerMentalState


func _init(profile: PlayerStatsProfile, mental_state: PlayerMentalState) -> void:
	_base = profile
	_mental_state = mental_state


func stamina_capacity() -> float:
	return _base.stamina_capacity()


func stamina_preservation() -> float:
	return _base.stamina_preservation() * lerpf(0.9, 1.0, _mental_state.pressure_modifier())


func stamina_recovery_rate() -> float:
	return _base.stamina_recovery_rate() * lerpf(0.92, 1.08, _mental_state.confidence)


func movement_speed_multiplier(stamina01: float) -> float:
	return _base.movement_speed_multiplier(stamina01)


func acceleration_multiplier(stamina01: float) -> float:
	return _base.acceleration_multiplier(stamina01)


func direction_change_resistance(stamina01: float) -> float:
	return _base.direction_change_resistance(stamina01)


func shot_side_skill01(is_backhand: bool) -> float:
	return _base.shot_side_skill01(is_backhand)


func shot_control01(stamina01: float) -> float:
	return _base.shot_control01(stamina01) * lerpf(0.75, 1.0, _mental_state.pressure_modifier())


func spin_control01(stroke_type: Stroke.StrokeType, stamina01: float) -> float:
	return _base.spin_control01(stroke_type, stamina01)


func serve_power01() -> float:
	return _base.serve_power01()


## Feel for the moment of contact: widens the window of a perfectly timed shot.
func timing01(stamina01: float) -> float:
	return _base.timing01(stamina01)


## Precision of a rally shot in [0, 1]: shot control, mixed with the return skill for a
## return of serve and with the net game (volley and net play) for a volley.
func rally_precision01(stamina01: float, is_return: bool, is_volley: bool) -> float:
	var precision: float = shot_control01(stamina01)
	if is_return:
		precision = lerpf(precision, _base.return01(), 0.5)
	if is_volley:
		precision = lerpf(precision, _base.net_game01(), 0.5)
	return precision


## Volley technique: sets the pace of volleys.
func volley01() -> float:
	return _base.volley01()


func serve_accuracy01(stamina01: float) -> float:
	return _base.serve_accuracy01(stamina01) * lerpf(0.8, 1.0, _mental_state.pressure_modifier())


func tactical_net_play01() -> float:
	return _base.net_play01()
