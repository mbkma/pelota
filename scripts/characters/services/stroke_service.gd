class_name StrokeService
extends RefCounted

var _queued_stroke: Stroke = null
var _last_consumed_decision: Stroke = null


func get_queued_stroke() -> Stroke:
	return _queued_stroke


func set_queued_stroke(stroke: Stroke) -> void:
	_queued_stroke = stroke


func clear() -> void:
	_queued_stroke = null
	_last_consumed_decision = null


func consume_controller_stroke_decision(
	controller: Controller,
	on_serve: Callable,
	on_rally_stroke: Callable
) -> void:
	if not controller:
		return

	var stroke_decision: Stroke = controller.get_stroke()
	if not stroke_decision:
		return

	if _last_consumed_decision == stroke_decision:
		return

	if stroke_decision.stroke_type == Stroke.StrokeType.SERVE:
		on_serve.call(stroke_decision)
	else:
		on_rally_stroke.call(stroke_decision)

	_last_consumed_decision = stroke_decision
