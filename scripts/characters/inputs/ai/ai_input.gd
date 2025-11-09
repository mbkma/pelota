## AI input handler that computes strokes and movement decisions automatically
class_name AiInput
extends InputMethod

## Available tactics for AI decision-making
@export var tactics: Dictionary[String, Script]

## Current tactic instance for stroke computation
var _current_tactic: Object

## Base position for AI movement (on the baseline)
var _pivot_point: Vector3 = Vector3.ZERO


func _ready() -> void:
	super()  # Call base class initialization
	if not validate_player():
		set_process(false)
		set_physics_process(false)
		return

	_current_tactic = tactics["default"]
	if not _current_tactic:
		push_error("AiInput: Failed to instantiate default tactic")
		set_process(false)
		return

	_current_tactic = _current_tactic.new()
	_current_tactic.setup(player)
	_pivot_point = Vector3(0, 0, sign(player.position.z) * GameConstants.COURT_LENGTH_HALF)

	# Connect to ball_hit signal to move to defensive position
	player.ball_hit.connect(_on_ball_hit)


## Request the AI to serve
func request_serve() -> void:
	make_serve()


## Process stroke decisions based on ball trajectory
func _process(_delta: float) -> void:
	if not validate_player():
		return

	if not player.ball:
		return

	var dist: float = GlobalUtils.get_horizontal_distance(player, player.ball)
	if (
		GlobalUtils.is_flying_towards(player, player.ball)
		and dist > GameConstants.AI_BALL_COMMIT_DISTANCE
	):
		if not player.queued_stroke:
			var closest_step: TrajectoryStep = GlobalUtils.get_closest_trajectory_step(player)
			if not closest_step:
				push_error("AiInput: Could not find ball trajectory step")
				return

			var closest_ball_position: Vector3 = closest_step.point
			if sign(closest_ball_position.z) != sign(player.position.z):
				return

			_do_stroke(closest_step)

	# if dist < 0 or player.ball.velocity.length() < 0.1:
	# 	player.cancel_stroke()


## Process movement decisions
func _physics_process(delta: float) -> void:
	if not validate_player():
		return

	var move_dir: Vector3 = player.compute_move_dir()
	player.apply_movement(move_dir, delta)


## Compute and execute a stroke for the given trajectory step
func _do_stroke(closest_step: TrajectoryStep) -> void:
	if not validate_player():
		push_error("AiInput._do_stroke: Invalid player state")
		return

	if not closest_step:
		push_error("AiInput._do_stroke: closest_step is null")
		return

	if not _current_tactic:
		push_error("AiInput._do_stroke: No tactic assigned")
		return

	var stroke: Stroke = _current_tactic.compute_next_stroke(closest_step)
	if not stroke:
		push_error("AiInput._do_stroke: Tactic returned null stroke")
		return

	player.queue_stroke(stroke)
	GlobalUtils.adjust_player_position_to_stroke(player, stroke)


## Initiate a serve using current tactic
func make_serve() -> void:
	if not validate_player():
		push_error("AiInput.make_serve: Invalid player state")
		return

	if not _current_tactic:
		push_error("AiInput.make_serve: No tactic assigned")
		return

	var stroke: Stroke = _current_tactic.compute_serve()
	if not stroke:
		push_error("AiInput.make_serve: Tactic returned null stroke")
		return

	player.prepare_serve()
	await get_tree().create_timer(GameConstants.INPUT_STARTUP_DELAY + 1.5).timeout
	player.serve(stroke)


## Setup AI for match manager integration
func setup(_match_manager: Object) -> void:
	pass


## Called when AI player hits the ball - move to defensive position
func _on_ball_hit() -> void:
	if not validate_player() or not player.ball:
		return

	# Calculate the position where opponent might hit the ball
	var closest_step: TrajectoryStep = GlobalUtils.get_closest_trajectory_step(player)
	if not closest_step:
		return

	var opponent_hit_position: Vector3 = closest_step.point

	# Calculate angle bisector position (best defensive position)
	var defensive_position: Vector3 = _calculate_angle_bisector_position(opponent_hit_position)

	# Move to the calculated position
	player.move_to(defensive_position)


## Calculate the angle bisector position (best defensive position)
## Returns the point that maximizes angle coverage to both corners
func _calculate_angle_bisector_position(opponent_hit_position: Vector3) -> Vector3:
	var court_width: float = GameConstants.COURT_WIDTH / 2.0
	var court_depth: float = GameConstants.COURT_LENGTH_HALF

	# Determine which side of court the opponent is hitting from
	var opponent_side: float = sign(opponent_hit_position.z)

	# The two extreme points the opponent could hit to (far corners on AI's side)
	var corner_left: Vector3 = Vector3(-court_width, 0, -opponent_side * court_depth)
	var corner_right: Vector3 = Vector3(court_width, 0, -opponent_side * court_depth)

	# Calculate vectors from opponent hit position to both corners
	var to_left: Vector3 = (corner_left - opponent_hit_position).normalized()
	var to_right: Vector3 = (corner_right - opponent_hit_position).normalized()

	# The bisector direction is the average of the two directions
	var bisector_direction: Vector3 = (to_left + to_right).normalized()

	# Position AI along the bisector, at a reasonable distance from opponent
	# The distance should be based on court positioning (around the baseline)
	var baseline_z: float = opponent_side * court_depth * 0.8
	var defensive_position: Vector3 = opponent_hit_position + bisector_direction * 5.0
	defensive_position.z = baseline_z

	return defensive_position
