## AI shot selection: plans the intent and lane of a shot from the situation and the player's
## play style, then builds the stroke.
class_name PointStrategy
extends RefCounted

var _player: Player
## Situation the pending stroke was planned in
var _context: AiPointContext


func _init(player: Player) -> void:
	_player = player


## Stroke meeting the ball at `step`, or a serve when `step` is null.
func compute_stroke(step: TrajectoryStep) -> Stroke:
	_context = AiPointContext.new(_player, step)
	ShotPlanner.plan(_context)
	_log("AI", _context)
	return ShotExecutor.build_stroke(_context, ShotExecutor.choose_stroke_type(_context))


## Aims `stroke`, planned by the last compute_stroke, again from where the opponent stands now,
## keeping its stroke type and intent.
func reaim(stroke: Stroke) -> void:
	_context.observe_opponent()
	ShotPlanner.aim(_context)
	_log("AI commits", _context)
	stroke.take_shot_from(ShotExecutor.build_stroke(_context, stroke.stroke_type))


func _log(label: String, context: AiPointContext) -> void:
	var message: String = (
		(
			"%s | %s lane=%s%s | Stamina: %.2f | Ball: %.2f m/s@%.2fm"
			% [
				label,
				AiPointContext.ShotIntent.keys()[context.intent],
				AiPointContext.TargetLane.keys()[context.target_lane],
				" (angle)" if context.is_angle else "",
				context.player_stamina_ratio,
				context.incoming_ball_speed,
				context.ball_position.y,
			]
		)
		+ (
			" | Stretch: %.2f | Opponent out of position: %.2f | Chance: %.2f"
			% [
				context.stretch,
				context.opponent_out_of_position,
				context.opportunity,
			]
		)
	)
	DebugLogger.log(_player, message)
