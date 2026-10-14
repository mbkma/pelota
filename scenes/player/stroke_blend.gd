## The stroke animation a swing plays: one stroke clip, or two clips of the same stroke type
## blended by `weight` (0 plays `low`, 1 plays `high`) to meet the ball at a height between theirs
## (see Model.get_stroke_blend). Both clips have the same markers; the blend plays on a common
## timeline whose marker times lie between theirs by `weight` (see PlayerAnimator).
class_name StrokeBlend
extends RefCounted

var low: StrokeClip
var high: StrokeClip
var weight: float


func _init(p_low: StrokeClip, p_high: StrokeClip, p_weight: float) -> void:
	low = p_low
	high = p_high
	weight = p_weight


func is_same_swing(other: StrokeBlend) -> bool:
	return other != null and other.low == low and other.high == high
