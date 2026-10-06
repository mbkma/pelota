## Human player controller: maps one InputDevice to movement, aiming and strokes.
##
## Rally: the direction moves the player. Pressing a stroke button commits to a shot: the
## player runs to the incoming ball on its own, the direction aims inside the opponent's
## court until the racket meets the ball and holding the button charges power.
## Releasing the button times the shot: the closer to contact, the smaller the area the ball
## may land in and the more extra pace the shot gets. Releasing within the perfect window
## before contact is a perfect shot; still holding at contact is the worst timing.
## Serve: before the serve the direction slides the server along the baseline. Pressing and
## holding a serve button picks the serve (STRIKE flat, SLICE slice, DROP_SHOT kick) and
## locks the server in place; the direction aims inside the service box for as long as the
## button is held. Releasing tosses the ball. Pressing any serve button again right before
## the racket meets the ball times the serve: the closer to contact, the faster and more
## precise it is. A serve that is not timed is weak and imprecise. The server stays locked
## until the ball is hit.
## The direction sets an aim goal per axis that is kept while the direction eases back
## toward neutral; the aim moves toward that goal at AIM_SPEED. The aim only resets to the
## middle after this player hits the ball, a new serve, or the end of the point.
## The aim marker shows the landing area: every shot draws one random direction inside it,
## and the ball lands at the aim plus that direction times the current radius.
## Close to the net, a stroke on a ball that has not bounced yet is played as a volley; the
## drop shot button plays a drop volley.
## Player stats shape all of it: shot side and volley skill set the stroke speed, spin skills
## the spin, timing widens the perfect windows, and precision (shot control, return skill,
## net game, serve accuracy, all reduced by pressure) shrinks the landing area.
class_name HumanController
extends Controller

enum Mode {
	## The direction moves the player.
	FREE,
	## A stroke button was pressed: auto-positioning to the ball, the direction aims.
	SHOT,
	## Waiting to serve: the direction slides the server along the baseline.
	SERVE_READY,
	## Serve button held: server locked, the direction aims into the service box.
	SERVE_AIM,
	## Serve button released: toss and swing; a press near contact times the serve.
	SERVE_SWING,
}

enum ServeType {
	FLAT,
	SLICE,
	KICK,
}

## Seconds a stroke button has to be held for full power.
const FULL_CHARGE_TIME: float = 0.8
## Extra stroke speed (m/s) at full charge.
const MAX_PACE: float = 5.0
## How fast the aim moves toward its goal, in aim ranges (center to line) per second.
const AIM_SPEED: float = 1.4
## Direction axis values below this count as neutral for aiming.
const AIM_NEUTRAL: float = 0.05
## An aim axis only follows the direction while it stays above this share of the push's peak,
## so the aim holds while the stick springs back.
const AIM_RELEASE_RATIO: float = 0.9
## How far ahead (m) the slide target along the baseline lies; sets the slide speed.
const SERVE_SLIDE_LOOKAHEAD: float = 1.1
## Closest the server may stand to the center mark (m).
const SERVE_CENTER_MARGIN: float = 0.3
## Aim targets stay this far inside the lines (m).
const AIM_LINE_MARGIN: float = 0.5
## Minimum alignment (cosine) of the direction with the one held when a shot ended for the
## direction to stay ignored.
const HELD_AIM_ALIGNMENT: float = 0.7
## Depth range (m from the net) of drop shot targets.
const DROP_SHOT_DEPTH_MIN: float = 1.5
const DROP_SHOT_DEPTH_MAX: float = 4.0

## Releasing the stroke button at most this many seconds before contact is perfect timing
## (for a player with average timing; the timing stat scales it).
const PERFECT_TIMING_WINDOW: float = 0.12
## Releasing this many seconds or more before contact is the worst timing.
const EARLIEST_TIMING: float = 0.8
## Extra stroke speed (m/s) of a perfectly timed shot; lower timing quality scales it down.
const TIMING_PACE_BONUS: float = 9.0
## Landing area radius (m) of a rally shot with perfect and with the worst timing.
const RALLY_ERROR_RADIUS_PERFECT: float = 0.25
const RALLY_ERROR_RADIUS_WORST: float = 2.5

## Pressing at most this many seconds before contact is a perfectly timed serve
## (for a player with average timing; the timing stat scales it).
const SERVE_PERFECT_WINDOW: float = 0.08
## Pressing this many seconds or more before contact (or not at all) is the worst timing.
const SERVE_EARLIEST_TIMING: float = 0.5
## Extra serve speed (m/s) of a perfectly timed serve; lower timing quality scales it down.
const SERVE_TIMING_PACE_BONUS: float = 7.0
## Landing area radius (m) of a serve with perfect and with the worst timing.
const SERVE_ERROR_RADIUS_PERFECT: float = 0.2
const SERVE_ERROR_RADIUS_WORST: float = 1.6
## Untimed serve speed (m/s) per serve type, from the weakest to the strongest server; a
## perfectly timed serve adds SERVE_TIMING_PACE_BONUS (slice up to ~110 mph, kick ~103 mph).
const SERVE_SPEED_RANGE: Dictionary[ServeType, Vector2] = {
	ServeType.FLAT: Vector2(46.0, 54.0),
	ServeType.SLICE: Vector2(36.0, 42.0),
	ServeType.KICK: Vector2(34.0, 39.0),
}
## Spin per serve type for a right-handed player (x: sidespin, y: topspin).
const SERVE_SPIN: Dictionary[ServeType, Vector3] = {
	ServeType.FLAT: Vector3(0.0, 0.2, 0.0),
	ServeType.SLICE: Vector3(0.75, 0.15, 0.0),
	ServeType.KICK: Vector3(-0.3, 1.0, 0.0),
}
## Speed factor of a second serve.
const SECOND_SERVE_SPEED_FACTOR: float = 0.88

var _device: InputDevice
var _mode: Mode = Mode.FREE

## Stroke button that started the current shot.
var _stroke_action: InputDevice.Action = InputDevice.Action.STRIKE
## Whether the stroke button is still held since the shot started.
var _charging: bool = false
var _charge_time: float = 0.0

## Aim within the current target area: x = left/right, y = short/deep, each in [-1, 1].
var _aim: Vector2 = Vector2.ZERO
## Where the aim is moving to, set by the direction.
var _aim_goal: Vector2 = Vector2.ZERO
## Peak deflection per axis of the current push of the direction.
var _aim_peak: Vector2 = Vector2.ZERO
## World position of the aim, derived from _aim.
var _aiming_at: Vector3 = Vector3.ZERO
## Sign of the server's x position, i.e. which half of the baseline it serves from.
var _serve_side: float = 1.0

## Stroke handed to the player (queued by the controller, executed by the player).
var _pending_stroke: Stroke = null
## Stroke speed of the current shot or serve before the timing bonus.
var _base_stroke_power: float = 0.0
## Precision in [0, 1] of the current rally shot (shot control, return and volley skill).
var _shot_precision: float = 0.5

## Random direction inside the unit circle, drawn once per shot or serve.
var _error_direction: Vector2 = Vector2.ZERO
## Timing quality in [0, 1] once the stroke button was released (shot) or pressed (serve).
var _timing_quality: float = 0.0
var _timed: bool = false

var _serve_type: ServeType = ServeType.FLAT
## Serve button held while aiming the serve.
var _serve_action: InputDevice.Action = InputDevice.Action.STRIKE

## Aim direction still held from the last shot or serve. Ignored for movement until the
## direction is released or clearly changed, so aiming does not make the player run off.
var _held_aim_direction: Vector2 = Vector2.ZERO


func _ready() -> void:
	super()
	var device_id: int = GlobalGameData.get_match_input_device(player.team_index)
	assert(
		device_id != InputDevice.NO_DEVICE_ID,
		"HumanController: no input device assigned to team %d" % player.team_index
	)
	_device = InputDevice.create(device_id)
	player.ball_hit.connect(_on_player_ball_hit)


## Update controller state - called by Player each frame
func update(delta: float) -> void:
	_device.poll()

	match _mode:
		Mode.FREE:
			var action: int = _just_pressed_action()
			if action >= 0:
				_begin_shot(action)
		Mode.SHOT:
			_update_shot(delta)
		Mode.SERVE_READY:
			var action: int = _just_pressed_action()
			if action >= 0:
				_begin_serve_aim(action)
		Mode.SERVE_AIM:
			_update_serve_aim(delta)
		Mode.SERVE_SWING:
			_update_serve_swing(delta)


func request_serve() -> void:
	_enter_free_mode()
	_mode = Mode.SERVE_READY
	_serve_side = signf(player.global_position.x)
	_reset_aim()
	_aiming_at = _serve_aim_target()


func on_lifecycle_phase_changed(_previous_phase: int, current_phase: int) -> void:
	match current_phase:
		MatchLifecycleBus.Phase.RALLY:
			if _mode == Mode.SERVE_SWING:
				_enter_free_mode()
		MatchLifecycleBus.Phase.POINT_ENDED, MatchLifecycleBus.Phase.IDLE:
			_enter_free_mode()
			_reset_aim()


func get_move_direction() -> Vector3:
	match _mode:
		Mode.FREE:
			return _to_world(_free_move_direction())
		Mode.SHOT:
			return player.compute_move_dir()
		Mode.SERVE_READY:
			return _serve_slide_direction()
	return Vector3.ZERO


func get_stroke() -> Stroke:
	return _pending_stroke


func get_aim_marker_position() -> Variant:
	return _aiming_at


func should_show_aim_marker() -> bool:
	return _mode != Mode.FREE


func get_aim_marker_radius() -> float:
	match _mode:
		Mode.SHOT:
			return _rally_error_radius(_displayed_shot_quality())
		Mode.SERVE_READY, Mode.SERVE_AIM:
			# Before the toss the marker shows the best the serve can get.
			return _serve_error_radius(1.0)
		Mode.SERVE_SWING:
			return _serve_error_radius(_displayed_serve_quality())
	return BallAimMarker.DEFAULT_RADIUS


func is_aim_marker_highlighted() -> bool:
	match _mode:
		Mode.SHOT:
			return _displayed_shot_quality() >= 1.0
		Mode.SERVE_SWING:
			return _displayed_serve_quality() >= 1.0
	return false


## Returns the stroke button pressed this frame, or -1.
func _just_pressed_action() -> int:
	for action in InputDevice.Action.values():
		if _device.is_action_just_pressed(action):
			return action
	return -1


func _draw_error_direction() -> void:
	_error_direction = Vector2.from_angle(randf() * TAU) * sqrt(randf())


## Rally
##########


func _begin_shot(action: InputDevice.Action) -> void:
	_mode = Mode.SHOT
	_stroke_action = action
	_charging = true
	_charge_time = 0.0
	_timed = false
	_draw_error_direction()
	_aiming_at = _rally_aim_target()


func _update_charge(delta: float) -> void:
	if not _charging:
		return
	if not _device.is_action_held(_stroke_action):
		_charging = false
		return
	_charge_time += delta


func _get_pace() -> float:
	return MAX_PACE * clampf(_charge_time / FULL_CHARGE_TIME, 0.0, 1.0)


func _update_shot(delta: float) -> void:
	var was_charging: bool = _charging
	_update_charge(delta)
	if was_charging and not _charging:
		_timed = true
		_timing_quality = _shot_timing_quality(player.get_seconds_to_contact())
	_update_aim(delta)
	_aiming_at = _rally_aim_target()

	# During the swing the stroke still follows aim and timing until the racket meets the ball.
	if player.get_current_state() == PlayerStateMachine.State.STROKING:
		if player.queued_stroke:
			_apply_shot_timing(player.queued_stroke)
		return

	if not _is_ball_incoming():
		# Released before the ball came, or the ball got past the player.
		if not _charging:
			_enter_free_mode()
		return

	var step: TrajectoryStep = get_closest_trajectory_step(player)
	if not step:
		return

	_pending_stroke = _build_rally_stroke(step)
	adjust_player_position_to_stroke(player, step, _pending_stroke)


## Timing quality in [0, 1] of releasing the stroke button `seconds_to_contact` before contact.
func _shot_timing_quality(seconds_to_contact: float) -> float:
	return _timing_quality_for(seconds_to_contact, PERFECT_TIMING_WINDOW, EARLIEST_TIMING)


## Timing quality the shot gets at contact: the release timing, or the worst while held.
func _effective_shot_quality() -> float:
	return _timing_quality if _timed else 0.0


## Timing quality shown by the aim marker: the release timing, or while the button is held
## the timing a release right now would give.
func _displayed_shot_quality() -> float:
	if _timed:
		return _timing_quality
	return _shot_timing_quality(player.get_seconds_to_contact())


func _rally_error_radius(quality: float) -> float:
	var radius: float = lerpf(RALLY_ERROR_RADIUS_WORST, RALLY_ERROR_RADIUS_PERFECT, quality)
	return radius * lerpf(1.25, 0.75, _shot_precision)


## Points a rally stroke at the current aim with its landing error and timing bonus.
func _apply_shot_timing(stroke: Stroke) -> void:
	var quality: float = _effective_shot_quality()
	var error: Vector2 = _error_direction * _rally_error_radius(quality)
	stroke.intended_stroke_target = _aiming_at
	stroke.stroke_target = _aiming_at + Vector3(error.x, 0.0, error.y)
	stroke.stroke_power = _base_stroke_power + TIMING_PACE_BONUS * quality


## Builds the rally stroke for the given contact step, forehand or backhand by ball side.
## Close to the net a ball taken before the bounce is volleyed (a drop shot becomes a drop
## volley).
func _build_rally_stroke(step: TrajectoryStep) -> Stroke:
	var to_ball: Vector3 = step.point - player.global_position
	var is_forehand: bool = to_ball.dot(player.global_basis.x) > 0.0
	var is_volley: bool = step.is_volley_contact()
	var stamina: float = player.get_stamina_ratio()

	var stroke: Stroke = Stroke.new()
	stroke.step = step
	if is_volley:
		_set_volley(stroke, is_forehand)
	else:
		_set_groundstroke(stroke, is_forehand, stamina)

	# Spin skill sets how much of the stroke's spin the player gets on the ball.
	var spin_skill: float = player.stats.spin_control01(stroke.stroke_type, stamina)
	stroke.stroke_spin.y *= lerpf(0.6, 1.1, spin_skill)

	_shot_precision = player.stats.rally_precision01(
		stamina, player.is_returning_serve(), is_volley
	)
	stroke.intended_stroke_power = stroke.stroke_power
	_base_stroke_power = stroke.stroke_power
	_apply_shot_timing(stroke)
	return stroke


## Volley or drop volley: a short punch with backspin; volley skill sets its pace.
func _set_volley(stroke: Stroke, is_forehand: bool) -> void:
	var volley_skill: float = player.stats.volley01()
	if _stroke_action == InputDevice.Action.DROP_SHOT:
		stroke.stroke_type = (
			Stroke.StrokeType.FOREHAND_DROP_VOLLEY
			if is_forehand
			else Stroke.StrokeType.BACKHAND_DROP_VOLLEY
		)
		stroke.stroke_power = lerpf(6.0, 10.0, volley_skill)
		stroke.stroke_spin = GameConstants.DROP_VOLLEY_SPIN
		return

	stroke.stroke_type = (
		Stroke.StrokeType.FOREHAND_VOLLEY if is_forehand else Stroke.StrokeType.BACKHAND_VOLLEY
	)
	stroke.stroke_power = lerpf(16.0, 24.0, volley_skill) + _get_pace() * 0.6
	stroke.stroke_spin = GameConstants.VOLLEY_SPIN


func _set_groundstroke(stroke: Stroke, is_forehand: bool, stamina: float) -> void:
	var pace: float = _get_pace()
	if _stroke_action == InputDevice.Action.DROP_SHOT:
		stroke.stroke_type = (
			Stroke.StrokeType.FOREHAND_DROP_SHOT
			if is_forehand
			else Stroke.StrokeType.BACKHAND_DROP_SHOT
		)
		var touch_skill: float = player.stats.spin_control01(stroke.stroke_type, stamina)
		stroke.stroke_power = lerpf(8.0, 14.0, touch_skill) + pace
		stroke.stroke_spin = GameConstants.AI_DROP_SHOT_SPIN
		return

	if is_forehand:
		stroke.stroke_type = Stroke.StrokeType.FOREHAND
		var fh_skill: float = player.stats.shot_side_skill01(false)
		# Typical rally forehand target: ~100 km/h (27.8 m/s).
		stroke.stroke_power = lerpf(24.0, 32.0, fh_skill) + pace
		stroke.stroke_spin = GameConstants.AI_FOREHAND_SPIN
		return

	var bh_skill: float = player.stats.shot_side_skill01(true)
	if _stroke_action == InputDevice.Action.SLICE:
		stroke.stroke_type = Stroke.StrokeType.BACKHAND_SLICE
		# Slices travel a little slower than drives: ~65-85 km/h (18-24 m/s).
		stroke.stroke_power = lerpf(18.0, 24.0, bh_skill) + pace
		stroke.stroke_spin = GameConstants.AI_BACKHAND_SLICE_SPIN
		return

	stroke.stroke_type = Stroke.StrokeType.BACKHAND
	# Typical rally backhand target near forehand baseline pace.
	stroke.stroke_power = lerpf(23.0, 31.0, bh_skill) + pace
	stroke.stroke_spin = GameConstants.AI_BACKHAND_SPIN


## Serve
##########


func _begin_serve_aim(action: InputDevice.Action) -> void:
	_mode = Mode.SERVE_AIM
	_serve_action = action
	match action:
		InputDevice.Action.SLICE:
			_serve_type = ServeType.SLICE
		InputDevice.Action.DROP_SHOT:
			_serve_type = ServeType.KICK
		_:
			_serve_type = ServeType.FLAT
	player.cancel_movement()


func _update_serve_aim(delta: float) -> void:
	_update_aim(delta)
	_aiming_at = _serve_aim_target()
	if _device.is_action_held(_serve_action):
		return

	# Releasing the serve button tosses the ball.
	_timed = false
	_draw_error_direction()
	_pending_stroke = _build_serve_stroke()
	_mode = Mode.SERVE_SWING


func _update_serve_swing(delta: float) -> void:
	_update_aim(delta)
	_aiming_at = _serve_aim_target()
	if not _timed and _just_pressed_action() >= 0:
		_timed = true
		_timing_quality = _serve_timing_quality(player.get_seconds_to_contact())
	_apply_serve_timing(_pending_stroke)


## Timing quality in [0, 1] of pressing `seconds_to_contact` before the serve contact.
func _serve_timing_quality(seconds_to_contact: float) -> float:
	return _timing_quality_for(seconds_to_contact, SERVE_PERFECT_WINDOW, SERVE_EARLIEST_TIMING)


func _displayed_serve_quality() -> float:
	if _timed:
		return _timing_quality
	return _serve_timing_quality(player.get_seconds_to_contact())


func _serve_error_radius(quality: float) -> float:
	var precision: float = player.stats.serve_accuracy01(player.get_stamina_ratio())
	var radius: float = lerpf(SERVE_ERROR_RADIUS_WORST, SERVE_ERROR_RADIUS_PERFECT, quality)
	return radius * lerpf(1.25, 0.75, precision)


## Points the serve at the current aim with its landing error and timing bonus.
func _apply_serve_timing(stroke: Stroke) -> void:
	var quality: float = _timing_quality if _timed else 0.0
	var error: Vector2 = _error_direction * _serve_error_radius(quality)
	stroke.intended_stroke_target = _aiming_at
	stroke.stroke_target = _aiming_at + Vector3(error.x, 0.0, error.y)
	stroke.stroke_power = _base_stroke_power + SERVE_TIMING_PACE_BONUS * quality


func _build_serve_stroke() -> Stroke:
	var stroke: Stroke = Stroke.new()
	stroke.stroke_type = Stroke.StrokeType.SERVE

	var speed_range: Vector2 = SERVE_SPEED_RANGE[_serve_type]
	_base_stroke_power = lerpf(speed_range.x, speed_range.y, player.stats.serve_power01())
	if player.match_manager.current_state == MatchManager.MatchState.SECOND_SERVE:
		_base_stroke_power *= SECOND_SERVE_SPEED_FACTOR
	stroke.intended_stroke_power = _base_stroke_power

	var spin: Vector3 = SERVE_SPIN[_serve_type]
	var stamina: float = player.get_stamina_ratio()
	match _serve_type:
		ServeType.SLICE:
			# Slice skill sets the sidespin of a slice serve.
			var slice_skill: float = player.stats.spin_control01(
				Stroke.StrokeType.BACKHAND_SLICE, stamina
			)
			spin *= lerpf(0.6, 1.1, slice_skill)
		ServeType.KICK:
			# Topspin skill sets the kick of a kick serve.
			var topspin_skill: float = player.stats.spin_control01(
				Stroke.StrokeType.FOREHAND, stamina
			)
			spin *= lerpf(0.6, 1.1, topspin_skill)
	if player.player_data.hand == "L":
		spin.x = -spin.x
	stroke.stroke_spin = spin

	_apply_serve_timing(stroke)
	return stroke


## Shared
###########


## Timing quality in [0, 1]: 1 within the perfect window before contact, falling to 0 at
## `earliest` seconds before contact. The player's timing stat scales the perfect window.
func _timing_quality_for(
	seconds_to_contact: float, perfect_window: float, earliest: float
) -> float:
	var timing_skill: float = player.stats.timing01(player.get_stamina_ratio())
	var window: float = perfect_window * lerpf(0.75, 1.35, timing_skill)
	var early_by: float = seconds_to_contact - window
	return 1.0 - clampf(early_by / (earliest - window), 0.0, 1.0)


## Sets the aim goal from the direction, per axis, and moves the aim toward it. Full
## deflection in any direction reaches the edge of the target area (diagonals reach the
## corners). An axis easing back toward neutral keeps its goal.
func _update_aim(delta: float) -> void:
	var direction: Vector2 = _device.get_direction()
	var largest_axis: float = maxf(absf(direction.x), absf(direction.y))
	if largest_axis == 0.0:
		_aim_peak = Vector2.ZERO
	else:
		var square: Vector2 = direction / largest_axis * direction.length()
		_update_aim_axis(Vector2.AXIS_X, square.x)
		_update_aim_axis(Vector2.AXIS_Y, square.y)
	_aim = _aim.move_toward(_aim_goal, AIM_SPEED * delta)


func _update_aim_axis(axis: int, value: float) -> void:
	var magnitude: float = absf(value)
	if magnitude < AIM_NEUTRAL:
		_aim_peak[axis] = 0.0
		return
	if signf(value) != signf(_aim_goal[axis]):
		# Pushing to the other side starts a new push.
		_aim_peak[axis] = 0.0
	if magnitude >= _aim_peak[axis] * AIM_RELEASE_RATIO:
		_aim_peak[axis] = maxf(_aim_peak[axis], magnitude)
		_aim_goal[axis] = value


func _reset_aim() -> void:
	_aim = Vector2.ZERO
	_aim_goal = Vector2.ZERO
	_aim_peak = Vector2.ZERO


func _enter_free_mode() -> void:
	if _mode != Mode.FREE:
		player.cancel_movement()
		_held_aim_direction = _device.get_direction()
	_mode = Mode.FREE
	_pending_stroke = null
	_charging = false
	_charge_time = 0.0


## Whether the ball moves toward this player's baseline and has not passed the player yet.
func _is_ball_incoming() -> bool:
	var ball: Ball = player.ball
	if not is_instance_valid(ball):
		return false
	var own_side: float = signf(player.global_position.z)
	var ball_in_front: bool = (ball.global_position.z - player.global_position.z) * own_side < 0.0
	return ball.velocity.z * own_side > 0.0 and ball_in_front


## Converts a device direction (x = right, y = forward) into a world direction for this player.
func _to_world(direction: Vector2) -> Vector3:
	var right: Vector3 = player.global_basis.x
	var forward: Vector3 = -player.global_basis.z
	var world: Vector3 = right * direction.x + forward * direction.y
	world.y = 0.0
	return world


func _free_move_direction() -> Vector2:
	var direction: Vector2 = _device.get_direction()
	if _held_aim_direction == Vector2.ZERO:
		return direction
	if (
		direction != Vector2.ZERO
		and direction.normalized().dot(_held_aim_direction.normalized()) >= HELD_AIM_ALIGNMENT
	):
		return Vector2.ZERO
	_held_aim_direction = Vector2.ZERO
	return direction


## Slides the server along the baseline, staying between the center mark and the sideline.
## Moves toward a clamped target so the server slows down at the limits instead of overshooting.
func _serve_slide_direction() -> Vector3:
	var slide: float = _device.get_direction().x
	if is_zero_approx(slide):
		player.cancel_movement()
		return Vector3.ZERO

	var bound_a: float = _serve_side * SERVE_CENTER_MARGIN
	var bound_b: float = _serve_side * GameConstants.COURT_WIDTH_HALF
	var target: Vector3 = (
		player.global_position + _to_world(Vector2(slide, 0.0)) * SERVE_SLIDE_LOOKAHEAD
	)
	target.x = clampf(target.x, minf(bound_a, bound_b), maxf(bound_a, bound_b))
	target.z = player.global_position.z
	player.request_move_to(target)
	return player.compute_move_dir()


## Rally target in the opponent's court: aim x picks the side, aim y the depth.
func _rally_aim_target() -> Vector3:
	var depth_min: float = GameConstants.SERVICE_LINE
	var depth_max: float = GameConstants.COURT_LENGTH_HALF - AIM_LINE_MARGIN
	if _stroke_action == InputDevice.Action.DROP_SHOT:
		depth_min = DROP_SHOT_DEPTH_MIN
		depth_max = DROP_SHOT_DEPTH_MAX

	var lateral: float = _aim.x * (GameConstants.COURT_WIDTH_HALF - AIM_LINE_MARGIN)
	var depth: float = lerpf(depth_min, depth_max, (_aim.y + 1.0) * 0.5)
	return _opponent_court_point(lateral, depth)


## Serve target in the diagonal service box: aim x picks the side, aim y the depth.
func _serve_aim_target() -> Vector3:
	var right_x: float = signf(player.global_basis.x.x)
	var box_sign: float = -_serve_side * right_x
	var inner: float = box_sign * AIM_LINE_MARGIN
	var outer: float = box_sign * (GameConstants.COURT_WIDTH_HALF - AIM_LINE_MARGIN)
	var lateral: float = lerpf(minf(inner, outer), maxf(inner, outer), (_aim.x + 1.0) * 0.5)
	var depth: float = lerpf(
		GameConstants.SERVICE_LINE * 0.5,
		GameConstants.SERVICE_LINE - AIM_LINE_MARGIN,
		(_aim.y + 1.0) * 0.5
	)
	return _opponent_court_point(lateral, depth)


## World point on the opponent's half: `lateral` along this player's right, `depth` from the net.
func _opponent_court_point(lateral: float, depth: float) -> Vector3:
	var right_x: float = signf(player.global_basis.x.x)
	var opponent_side: float = -signf(player.global_position.z)
	return Vector3(lateral * right_x, 0.0, depth * opponent_side)


func _on_player_ball_hit() -> void:
	if _mode == Mode.SHOT:
		_enter_free_mode()
	_reset_aim()
	_device.vibrate(0.64, 0.4, 0.1)
