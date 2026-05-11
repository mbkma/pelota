class_name AiPlayStyle
extends Resource

@export var style_name: StringName = &"default"

@export_range(0.0, 1.0, 0.01) var aggression: float = 0.5
@export_range(0.0, 1.0, 0.01) var risk_tolerance: float = 0.5
@export_range(0.0, 1.0, 0.01) var net_frequency: float = 0.2
@export_range(0.0, 1.0, 0.01) var preferred_rally_pace: float = 0.5

@export_range(0.0, 5.0, 0.01) var neutral_intent_weight: float = 1.0
@export_range(0.0, 5.0, 0.01) var attack_intent_weight: float = 1.0
@export_range(0.0, 5.0, 0.01) var defend_intent_weight: float = 1.0
@export_range(0.0, 5.0, 0.01) var approach_net_intent_weight: float = 1.0
@export_range(0.0, 5.0, 0.01) var serve_intent_weight: float = 1.0

@export var rally_patterns: Array[ShotPattern] = []
@export var serve_patterns: Array[ShotPattern] = []


func get_patterns(for_serve: bool) -> Array[ShotPattern]:
	return serve_patterns if for_serve else rally_patterns


func get_intent_weight(intent: ShotPattern.TacticalIntent) -> float:
	match intent:
		ShotPattern.TacticalIntent.NEUTRAL:
			return neutral_intent_weight
		ShotPattern.TacticalIntent.ATTACK:
			return attack_intent_weight
		ShotPattern.TacticalIntent.DEFEND:
			return defend_intent_weight
		ShotPattern.TacticalIntent.APPROACH_NET:
			return approach_net_intent_weight
		ShotPattern.TacticalIntent.SERVE:
			return serve_intent_weight
		_:
			return 1.0
