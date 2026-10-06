## A stroke animation together with the racket contact point it reaches at its `hit` marker.
## Place it where the racket meets the ball at the hit frame (in model space).
## The Model picks the clip whose contact height is closest to the ball for a given stroke type.
class_name StrokeClip
extends Marker3D

## Animation in the player AnimationLibrary. Must have a `hit` marker
## and must be an input of the StrokeSelect transition in the player AnimationTree.
@export var animation: StringName
## Stroke types this clip can play.
@export var stroke_types: Array[Stroke.StrokeType] = []


func supports(stroke_type: Stroke.StrokeType) -> bool:
	return stroke_type in stroke_types
