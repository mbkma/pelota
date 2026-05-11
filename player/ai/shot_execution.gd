class_name ShotExecution
extends RefCounted


func build_stroke(
	pattern: ShotPattern,
	context: AiPointContext,
	targeting: NormalizedCourtTargeting
) -> Stroke:
	if not pattern or not context or not targeting:
		return null

	var stroke := Stroke.new()
	stroke.stroke_type = pattern.stroke_type
	stroke.stroke_power = pattern.stroke_power
	stroke.stroke_spin = pattern.stroke_spin
	stroke.stroke_target = targeting.to_world_target(
		pattern.normalized_target,
		context.player_position,
		context.is_serve
	)
	stroke.step = context.closest_step
	return stroke
