class_name Stroke
extends Resource

# Enum for stroke types
enum StrokeType {
	FOREHAND,
	FOREHAND_DROP_SHOT,
	BACKHAND,
	SERVE,
	BACKHAND_SLICE,
	BACKHAND_DROP_SHOT,
	FOREHAND_VOLLEY,
	BACKHAND_VOLLEY,
	FOREHAND_DROP_VOLLEY,
	BACKHAND_DROP_VOLLEY,
}

# Variables for stroke properties
var stroke_type: StrokeType
## Forward speed (m/s) of the ball off the racket for a shot played as planned.
var stroke_power: float
## Extra forward speed (m/s) the shot only gets when the player meets the ball in position and
## set early with time to spare (see Player); weaker contact gets a share of it.
var attack_power: float = 0.0
var stroke_spin: Vector3
var stroke_target: Vector3
var intended_stroke_power: float
var intended_stroke_target: Vector3

# The TrajectoryStep nearest to the players z-position
var step: TrajectoryStep

# Shot intent for debug/UI display (mirrors AiPointContext.ShotIntent, -1 = unknown)
var stroke_intent: int = -1


## Whether the stroke is played before the ball bounces, close to the net.
func is_volley() -> bool:
	return stroke_type in [
		StrokeType.FOREHAND_VOLLEY,
		StrokeType.BACKHAND_VOLLEY,
		StrokeType.FOREHAND_DROP_VOLLEY,
		StrokeType.BACKHAND_DROP_VOLLEY,
	]


## Whether the stroke is a soft touch shot (drop shot or drop volley).
func is_drop() -> bool:
	return stroke_type in [
		StrokeType.FOREHAND_DROP_SHOT,
		StrokeType.BACKHAND_DROP_SHOT,
		StrokeType.FOREHAND_DROP_VOLLEY,
		StrokeType.BACKHAND_DROP_VOLLEY,
	]
