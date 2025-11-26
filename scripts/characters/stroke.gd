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
	VOLLEY,
}

# Variables for stroke properties
var stroke_type: StrokeType
var stroke_power: float
var stroke_spin: Vector3
var stroke_target: Vector3

# step contains information about where and when to hit the ball
var step: TrajectoryStep
