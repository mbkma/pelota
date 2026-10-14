## A stroke animation and the stroke types it plays. Where its racket meets the ball (the racket's
## sweet spot at the animation's `hit` marker) follows from the animation on the player's body
## (see Model.get_contact_point).
class_name StrokeClip
extends Resource

## Animation in the player AnimationLibrary. Must have a `hit` marker
## and must be an input of the StrokeSelect transition in the player AnimationTree.
@export var animation: StringName
## Stroke types this clip can play.
@export var stroke_types: Array[Stroke.StrokeType] = []


func supports(stroke_type: Stroke.StrokeType) -> bool:
	return stroke_type in stroke_types
