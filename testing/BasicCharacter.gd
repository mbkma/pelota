extends CharacterBody3D

@export var model_scene: Resource

var velocity := Vector3.ZERO
@export var max_speed: = 2.0
@export var move_speed: = 2.0
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var _playback: AnimationNodeStateMachinePlayback = animation_tree["parameters/playback"]

func _ready() -> void:
	animation_tree.active = true


static func get_input_direction() -> Vector3:
	return Vector3(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			0,
			Input.get_action_strength("move_back") - Input.get_action_strength("move_front")
		)


func _physics_process(delta: float) -> void:
	var move_direction := get_input_direction()


	if move_direction != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(move_direction.x, move_direction.z), 15*delta)

	if move_direction.length() > 1.0:
		move_direction = move_direction.normalized()

	velocity = move_direction * move_speed
	velocity.y = 0

	set_velocity(velocity)
	set_up_direction(Vector3.UP)
	move_and_slide()

	if velocity.length() > 0.0:
		_playback.travel("walk-loop")
	else:
		_playback.travel("idle-loop")
