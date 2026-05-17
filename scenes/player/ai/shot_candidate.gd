class_name ShotCandidate
extends RefCounted

var intent: int = AiPointContext.ShotIntent.NEUTRAL
var tactical_value: float = 0.0
var style_preference: float = 0.0
var comfort: float = 0.0
var opponent_exploitation: float = 0.0
var risk: float = 0.5
var execution_difficulty: float = 0.5
var score: float = 0.0


func to_debug_string() -> String:
	var intent_name: String = AiPointContext.ShotIntent.keys()[intent] if intent < AiPointContext.ShotIntent.size() else "UNKNOWN"
	return "%s score=%.2f style=%.2f tact=%.2f comfort=%.2f exploit=%.2f risk=%.2f diff=%.2f" % [
		intent_name,
		score,
		style_preference,
		tactical_value,
		comfort,
		opponent_exploitation,
		risk,
		execution_difficulty,
	]