class_name ShotPattern
extends Resource

enum TacticalIntent {
	ANY,
	NEUTRAL,
	ATTACK,
	DEFEND,
	APPROACH_NET,
	SERVE,
}

enum BallSide {
	ANY,
	FOREHAND,
	BACKHAND,
}

@export var pattern_name: StringName
@export var stroke_type: Stroke.StrokeType = Stroke.StrokeType.FOREHAND
@export var stroke_power: float = 16.0
@export var stroke_spin: Vector3 = Vector3.ZERO

# Normalized target where x is lateral (-1 crosscourt, 1 line) and y is depth (-1 short, 1 deep)
@export var normalized_target: Vector2 = Vector2.ZERO

@export_range(0.0, 100.0, 0.01) var base_weight: float = 1.0
@export_range(0.0, 1.0, 0.01) var risk_level: float = 0.5
@export var tactical_intent: TacticalIntent = TacticalIntent.NEUTRAL
@export var allowed_ball_side: BallSide = BallSide.ANY

# Optional contextual constraints to gate pattern availability
@export var min_incoming_ball_speed: float = 0.0
@export var max_incoming_ball_speed: float = 1000.0
@export var min_ball_height: float = -10.0
@export var max_ball_height: float = 100.0
@export var min_player_movement_speed: float = 0.0
@export var max_player_movement_speed: float = 100.0


func allows_context(context: AiPointContext, intent: TacticalIntent) -> bool:
	if not context:
		return false
	if tactical_intent != TacticalIntent.ANY and intent != tactical_intent:
		return false

	match allowed_ball_side:
		BallSide.FOREHAND:
			if context.ball_side != AiPointContext.BallSide.FOREHAND:
				return false
		BallSide.BACKHAND:
			if context.ball_side != AiPointContext.BallSide.BACKHAND:
				return false
		_:
			pass

	if context.incoming_ball_speed < min_incoming_ball_speed:
		return false
	if context.incoming_ball_speed > max_incoming_ball_speed:
		return false
	if context.ball_height < min_ball_height:
		return false
	if context.ball_height > max_ball_height:
		return false
	if context.player_movement_speed < min_player_movement_speed:
		return false
	if context.player_movement_speed > max_player_movement_speed:
		return false

	return true
