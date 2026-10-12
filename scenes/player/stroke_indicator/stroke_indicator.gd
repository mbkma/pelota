## Filled circle above a human player's head while the stroke button can be used. Its color shows
## the timing a release of the button right now would give: red too early, through amber, to
## green within the perfect window; once the button is released, the timing the shot got.
class_name StrokeIndicator
extends Sprite3D

const EARLY_COLOR := Color(0.9, 0.2, 0.15)
const CLOSE_COLOR := Color(1.0, 0.72, 0.2)
const PERFECT_COLOR := Color(0.3, 0.9, 0.35)


## Shows the timing `quality` in [0, 1] (1: perfect).
func set_quality(quality: float) -> void:
	if quality < 0.5:
		modulate = EARLY_COLOR.lerp(CLOSE_COLOR, quality * 2.0)
	else:
		modulate = CLOSE_COLOR.lerp(PERFECT_COLOR, (quality - 0.5) * 2.0)
