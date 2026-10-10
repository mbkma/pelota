## Mental state of a player during a match. Before every point, pressure and confidence move
## toward what the match situation gives:
## - Pressure comes mostly from defending a break, set or match point and from trailing on the
##   score; a hopeless deficit releases it again (nothing left to lose). Serving it out on a set
##   or match point and a tiebreak add a little.
## - Confidence comes mostly from the score standing and the games won lately, and a little from
##   well-hit strokes.
## Composure and clutch are the player's traits: they absorb part of the pressure (see
## pressure_modifier).
class_name PlayerMentalState
extends RefCounted

## Pressure of defending a point that would decide this for the opponent
const DEFENDING_PRESSURE: Dictionary[Score.PointImportance, float] = {
	Score.PointImportance.BREAK: 0.5,
	Score.PointImportance.SET: 0.65,
	Score.PointImportance.MATCH: 0.8,
}
## Pressure of a point that would decide this for the player itself
const CLOSING_PRESSURE: Dictionary[Score.PointImportance, float] = {
	Score.PointImportance.SET: 0.2,
	Score.PointImportance.MATCH: 0.3,
}
## Pressure of any tiebreak point
const TIEBREAK_PRESSURE: float = 0.2
## Pressure of trailing at its worst: it rises with the deficit (see Score.standing), peaks at
## half the scale and fades toward a hopeless deficit.
const TRAILING_PRESSURE: float = 0.4
## Share of the way pressure and confidence move toward the situation before each point
const PRESSURE_ADAPTATION: float = 0.6
const CONFIDENCE_ADAPTATION: float = 0.3
## Confidence gained (lost) at full standing, momentum and stroke form, around 0.5
const CONFIDENCE_FROM_STANDING: float = 0.25
const CONFIDENCE_FROM_MOMENTUM: float = 0.2
const CONFIDENCE_FROM_FORM: float = 0.08
## Share of the way momentum moves toward each game result and form toward each stroke
const MOMENTUM_ADAPTATION: float = 0.35
const FORM_ADAPTATION: float = 0.12

var composure: float
var clutch: float
var confidence: float = 0.5
var pressure: float = 0.0
## Games won (1) or lost (-1) lately, recent ones weighing most
var _momentum: float = 0.0
## How well the player has hit the ball lately, in [-1, 1]
var _form: float = 0.0


## Starts the match with the player's mental traits; confidence and pressure start neutral.
func _init(profile: PlayerStatsProfile) -> void:
	composure = profile.value01(profile.composure)
	clutch = profile.value01(profile.clutch)


## Moves pressure and confidence toward the situation of the next point for `player_index`.
func before_point(score: Score, player_index: int) -> void:
	pressure = lerpf(pressure, _situation_pressure(score, player_index), PRESSURE_ADAPTATION)
	var situation_confidence: float = clampf(
		(
			0.5
			+ CONFIDENCE_FROM_STANDING * score.standing(player_index)
			+ CONFIDENCE_FROM_MOMENTUM * _momentum
			+ CONFIDENCE_FROM_FORM * _form
		),
		0.0,
		1.0
	)
	confidence = lerpf(confidence, situation_confidence, CONFIDENCE_ADAPTATION)


func on_game_result(won: bool) -> void:
	_momentum = lerpf(_momentum, 1.0 if won else -1.0, MOMENTUM_ADAPTATION)


## A stroke hit with `quality` in [0, 1] (1: perfectly hit).
func on_stroke(quality: float) -> void:
	_form = lerpf(_form, quality * 2.0 - 1.0, FORM_ADAPTATION)


## How well the player copes with the current pressure, in [0, 1] (1 = unaffected).
## Composure and clutch absorb part of the pressure.
func pressure_modifier() -> float:
	var resilience: float = (composure * 0.55) + (clutch * 0.45)
	return clampf(1.0 - pressure * (1.0 - resilience * 0.8), 0.0, 1.0)


func _situation_pressure(score: Score, player_index: int) -> float:
	var big_point: float = maxf(
		DEFENDING_PRESSURE.get(score.point_importance(1 - player_index), 0.0),
		CLOSING_PRESSURE.get(score.point_importance(player_index), 0.0)
	)
	if score.is_tiebreak:
		big_point = maxf(big_point, TIEBREAK_PRESSURE)
	var deficit: float = maxf(-score.standing(player_index), 0.0)
	var trailing: float = TRAILING_PRESSURE * 4.0 * deficit * (1.0 - deficit)
	return clampf(big_point + trailing, 0.0, 1.0)
