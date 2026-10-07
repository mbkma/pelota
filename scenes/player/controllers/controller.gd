## Base class for player control (human/AI): decides movement and strokes for its player.
@abstract class_name Controller
extends Node

## Contact height range (m) of a comfortable groundstroke, used for the ideal position
const IDEAL_CONTACT_HEIGHT_MIN: float = 0.7
const IDEAL_CONTACT_HEIGHT_MAX: float = 1.4
## Lowest ball height (m) a stroke can still reach
const MIN_CONTACT_HEIGHT: float = 0.2

## Player this controller drives
var player: Player


func _init(controlled_player: Player) -> void:
	player = controlled_player


## Update controller state - called by Player each frame
@abstract func update(delta: float) -> void

## Request the controller to initiate a serve
@abstract func request_serve() -> void

## Desired movement direction; its length is the share of the top speed.
@abstract func get_move_direction() -> Vector3

## Stroke the controller wants to play, null if none.
@abstract func get_stroke() -> Stroke


func ball_changed(_ball: Ball) -> void:
	pass


## Lifecycle callback from the player's lifecycle bus (serve/rally/point phases)
func on_lifecycle_phase_changed(_current_phase: MatchLifecycleBus.Phase) -> void:
	pass


## Aim marker position; null hides the marker.
func get_aim_marker_position() -> Variant:
	return null


## Where the player should stand to meet the incoming ball, shown by the ideal position
## marker; null hides the marker.
func get_ideal_position() -> Variant:
	return null


## Radius (m) in which the aimed stroke may land, shown by the aim marker
func get_aim_marker_radius() -> float:
	return BallAimMarker.DEFAULT_RADIUS


## Whether the aim marker should be highlighted (e.g. perfectly timed stroke)
func is_aim_marker_highlighted() -> bool:
	return false


## Moves the player to where the racket contact point of `stroke` meets the ball at `step`.
func move_to_contact(step: TrajectoryStep, stroke: Stroke) -> void:
	player.request_move_to(position_for_contact(step, stroke))


## Where the player has to stand so the racket contact point of `stroke` meets the ball at
## `step`.
func position_for_contact(step: TrajectoryStep, stroke: Stroke) -> Vector3:
	var contact_to_body: Vector3 = (
		player.model.get_racket_contact_point(stroke) - player.global_position
	)
	contact_to_body.y = 0.0
	var body_position: Vector3 = step.point - contact_to_body
	body_position.y = player.position.y
	return body_position


## Best point to meet the incoming ball: a volley if the ball can be taken before the bounce
## in the net zone, otherwise where it passes a comfortable height after the bounce, nearest
## to the player (else the apex after the bounce).
func get_ideal_contact_step() -> TrajectoryStep:
	var trajectory: Array[TrajectoryStep] = player.ball.predict_trajectory()
	var closest_step: TrajectoryStep = _closest_playable_step(trajectory)
	if closest_step and closest_step.is_volley_contact():
		return closest_step

	var best_step: TrajectoryStep = null
	for step in trajectory:
		if step.bounces != 1:
			continue
		if step.point.y < IDEAL_CONTACT_HEIGHT_MIN or step.point.y > IDEAL_CONTACT_HEIGHT_MAX:
			continue
		if not best_step or _z_distance(step) < _z_distance(best_step):
			best_step = step
	if best_step:
		return best_step
	var apex: TrajectoryStep = _closest_apex_after_first_bounce(trajectory)
	return apex if apex else closest_step


## Where the player should stand to meet the ball at `step` with a forehand or backhand
## (whichever side the ball is on).
func ideal_position_for_step(step: TrajectoryStep) -> Vector3:
	var stroke := Stroke.new()
	stroke.step = step
	var is_forehand: bool = (step.point - player.global_position).dot(player.global_basis.x) > 0.0
	if step.is_volley_contact():
		stroke.stroke_type = (
			Stroke.StrokeType.FOREHAND_VOLLEY if is_forehand else Stroke.StrokeType.BACKHAND_VOLLEY
		)
	else:
		stroke.stroke_type = (
			Stroke.StrokeType.FOREHAND if is_forehand else Stroke.StrokeType.BACKHAND
		)
	return position_for_contact(step, stroke)


## Apex after the first bounce closest to the player by Z distance.
func get_closest_apex_after_first_bounce() -> TrajectoryStep:
	return _closest_apex_after_first_bounce(player.ball.predict_trajectory())


## Playable trajectory step (before the second bounce, high enough to reach) closest to the
## player by Z distance. A ball dying short of the player (e.g. a drop shot) is met at the last
## step it can still be played.
func get_closest_trajectory_step() -> TrajectoryStep:
	return _closest_playable_step(player.ball.predict_trajectory())


func _closest_playable_step(trajectory: Array[TrajectoryStep]) -> TrajectoryStep:
	var closest_step: TrajectoryStep = null
	for step in trajectory:
		if step.bounces > 1:
			break
		if step.point.y < MIN_CONTACT_HEIGHT:
			continue
		if not closest_step or _z_distance(step) < _z_distance(closest_step):
			closest_step = step
	return closest_step


func _closest_apex_after_first_bounce(trajectory: Array[TrajectoryStep]) -> TrajectoryStep:
	var closest_step: TrajectoryStep = null
	for i in trajectory.size():
		var step: TrajectoryStep = trajectory[i]
		if step.bounces != 1:
			continue
		var previous_y: float = trajectory[maxi(i - 1, 0)].point.y
		var next_y: float = trajectory[mini(i + 1, trajectory.size() - 1)].point.y
		var is_apex: bool = step.point.y >= previous_y and step.point.y >= next_y
		if is_apex and (not closest_step or _z_distance(step) < _z_distance(closest_step)):
			closest_step = step
	return closest_step


func _z_distance(step: TrajectoryStep) -> float:
	return absf(step.point.z - player.global_position.z)
