class_name Stroke
extends Resource

# Enum for stroke types
enum StrokeType {
	FOREHAND,
	BACKHAND,
	SERVE,
	BACKHAND_SLICE,
	VOLLEY,
}

# Variables for stroke properties
var stroke_type: StrokeType
var stroke_power: float
var stroke_spin: float
var stroke_target: Vector3

# time until the ball enters racket
var timing: float
