## AI shot selection: plans the intent and lane of a shot from the situation and the player's
## play style, then builds the stroke.
class_name PointStrategy
extends RefCounted

var _player: Player


func _init(player: Player) -> void:
	_player = player


## Stroke meeting the ball at `step`, or a serve when `step` is null.
func compute_stroke(step: TrajectoryStep) -> Stroke:
	var context := AiPointContext.new(_player, step)
	ShotPlanner.plan(context)
	var message: String = (
		(
			"AI | %s lane=%s | Stamina: %.2f | Ball: %.2f m/s@%.2fm"
			% [
				AiPointContext.ShotIntent.keys()[context.intent],
				AiPointContext.TargetLane.keys()[context.target_lane],
				context.player_stamina_ratio,
				context.incoming_ball_speed,
				context.ball_position.y,
			]
		)
		+ (
			" | Player speed: %.2f | Opp dist: %.2f"
			% [context.player_movement_speed, context.opponent_center_distance]
		)
	)
	DebugLogger.log(_player, message)
	return ShotExecutor.build_stroke(context)
