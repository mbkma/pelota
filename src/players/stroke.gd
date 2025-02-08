class_name Stroke
extends Node

# Enum for stroke types
enum StrokeType {
	FOREHAND,
	BACKHAND,
	SERVE,
	BACKHAND_SLICE,
	VOLLEY,
}

@onready var stroke_sounds_flat := $Sounds/Flat.get_children()
@onready var stroke_sounds_slice := $Sounds/Slice.get_children()

var player: Player

# Variables for stroke properties
var stroke_type: StrokeType
var stroke_power: float
var stroke_spin: float
var stroke_target: Vector3


func _ready() -> void:
	player = get_parent()


# Called when the stroke is executed
func execute_stroke(ball: Ball) -> void:
	var vel = GlobalPhysics.calculate_velocity(
		ball.position, stroke_target, -sign(player.position.z) * stroke_power, stroke_spin
	)
	print(stroke_target)
	print("ball_hit. speed: ", vel.length() * 3.6, "km/h vel: ", vel)
	#vel = Vector3(0,0,-5)
	print("Velocity Local:", vel)
	ball.apply_stroke(vel, stroke_spin)
	_play_stroke_sound()
	print("Velocity Global:", ball.velocity)


func _play_stroke_sound() -> void:
	if stroke_type == StrokeType.BACKHAND_SLICE:
		stroke_sounds_slice[randi() % stroke_sounds_slice.size()].play()
	else:
		stroke_sounds_flat[randi() % stroke_sounds_flat.size()].play()


# Play the stroke animation
func play_animation() -> void:
	pass
