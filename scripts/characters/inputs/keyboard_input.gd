## Human player input handler for keyboard/mouse controls
## Manages movement, aiming, and stroke execution
class_name HumanInput
extends InputMethod

## Local signal for aiming position (parent class has aiming_at_position)
signal aiming_at_pos(position: Vector3)

## Input state flags
var _move_input_blocked: bool = false
var _stroke_input_blocked: bool = true
var _input_blocked: bool = false

## Mouse/stroke tracking
var _mouse_from: Vector2 = Vector2.ZERO
var _mouse_to: Vector2 = Vector2.ZERO
var _aiming_at: Vector3 = Vector3.ZERO
var _input_pace: float = 0.0
var _serve_controls: bool = false


func _ready() -> void:
	super()  # Call base class initialization
	if not validate_player():
		set_process(false)
		set_physics_process(false)
		return

	if not player.ball_aim_marker:
		push_error("HumanInput: ball_aim_marker not assigned in editor")
		set_process(false)
		return

	await get_tree().create_timer(GameConstants.INPUT_STARTUP_DELAY).timeout
	_stroke_input_blocked = false
	player.ball_aim_marker.global_position = _get_default_aim()
	player.ball_aim_marker.visible = true
	player.ball_hit.connect(_on_player_ball_hit)


func _process(_delta: float) -> void:
	if player and player.ball:
		var distance_to_ball: float = GlobalUtils.get_horizontal_distance(player, player.ball)
		if (
			distance_to_ball < 0
			or player.ball.velocity.length() < GameConstants.BALL_VELOCITY_CANCELLATION_THRESHOLD
		):
			player.cancel_stroke()
			_move_input_blocked = false

	# Handle stroke input
	if not _stroke_input_blocked:
		if Input.is_action_just_pressed("strike"):
			_input_pace = 0.0
			_mouse_from = get_viewport().get_mouse_position()

		if Input.is_action_pressed("strike"):
			_input_pace += GameConstants.PACE_INCREMENT_RATE
			pace_changed.emit(_input_pace)
			_mouse_to = get_viewport().get_mouse_position()
			_aiming_at = _get_aim_pos(_mouse_from, _mouse_to)
			player.ball_aim_marker.global_position = _aiming_at
			player.ball_aim_marker.visible = true

		if Input.is_action_just_released("strike"):
			if _serve_controls:
				_do_serve(_aiming_at, _input_pace)
				_serve_controls = false
			else:
				if not player.ball:
					printerr("Player has no ball")
				else:
					_do_stroke(_aiming_at, _input_pace)

	# Handle challenge input
	if Input.is_action_just_pressed("challenge"):
		player.challenge()


func request_serve() -> void:
	_serve_controls = true


func _physics_process(_delta: float) -> void:
	if _input_blocked:
		return

	if _move_input_blocked:
		var move_direction: Vector3 = player.compute_move_dir()
		player.apply_movement(move_direction, _delta)
	else:
		var move_direction: Vector3 = _get_move_direction()
		player.apply_movement(move_direction, _delta)


## Computes move direction from input relative to camera orientation
func _get_move_direction() -> Vector3:
	var raw_input: Vector3 = Vector3(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		0.0,
		Input.get_action_strength("move_front") - Input.get_action_strength("move_back")
	)

	var camera_basis: Basis = player.camera.global_basis
	var forward: Vector3 = -camera_basis.z.normalized()
	var right: Vector3 = camera_basis.x.normalized()

	# Invert left/right for back player to match their reversed camera perspective
	var lr_multiplier: float = sign(player.position.z)
	var direction: Vector3 = (
		(forward * raw_input.z + right * raw_input.x * lr_multiplier).normalized()
	)

	return direction


## Gets default aiming position based on context (serve vs rally)
func _get_default_aim() -> Vector3:
	var default_aim: Vector3 = Vector3(
		0.0, 0.0, -sign(player.position.z) * GameConstants.AIM_FRONT_COURT
	)

	if _serve_controls:
		default_aim = Vector3(
			-sign(player.position.x) * GameConstants.AIM_BACK_COURT,
			0.0,
			-sign(player.position.z) * GameConstants.AIM_SERVE
		)

	return default_aim


## Calculates aim position with mouse offset from default
func _get_aim_pos(mouse_start: Vector2, mouse_current: Vector2) -> Vector3:
	var default_aim: Vector3 = _get_default_aim()
	var mouse_delta: Vector2 = mouse_current - mouse_start
	var mouse_sensitivity: float = GameConstants.MOUSE_SENSITIVITY

	var aim_position: Vector3 = default_aim
	aim_position.z += sign(player.position.z) * mouse_delta.y / mouse_sensitivity
	aim_position.x += sign(player.position.z) * mouse_delta.x / mouse_sensitivity

	return aim_position


## Executes a serve stroke
func _do_serve(aim_position: Vector3, pace: float) -> void:
	if not validate_player():
		push_error("HumanInput._do_serve: Invalid player state")
		return

	var stroke: Stroke = Stroke.new()
	stroke.stroke_type = Stroke.StrokeType.SERVE
	stroke.stroke_power = float(player.stats.get("serve_pace", 30.0)) + pace
	stroke.stroke_spin = 0.0
	stroke.stroke_target = aim_position

	player.serve(stroke)


## Executes a rally stroke (forehand/backhand/slice)
func _do_stroke(aim_position: Vector3, pace: float) -> void:
	if not validate_player():
		push_error("HumanInput._do_stroke: Invalid player state")
		return

	if not player.ball:
		push_error("HumanInput._do_stroke: Player has no ball to stroke")
		return

	var closest_step: TrajectoryStep = GlobalUtils.get_closest_trajectory_step(player)
	if not closest_step:
		push_error("HumanInput._do_stroke: Could not find ball trajectory step")
		return

	var closest_ball_position: Vector3 = closest_step.point

	# Ensure ball is on same side of court as player
	if sign(closest_ball_position.z) != sign(player.position.z):
		push_error(
			"HumanInput._do_stroke: Ball is on opposite side of court (player: ",
			player.position.z,
			", ball: ",
			closest_ball_position.z,
			")"
		)
		return

	var stroke: Stroke = _construct_stroke_from_input(closest_step, aim_position, pace)
	_move_input_blocked = true

	player.queue_stroke(stroke)
	GlobalUtils.adjust_player_position_to_stroke(player, stroke)

	_clear_stroke_input()


## Clears stroke input state after executing a stroke
func _clear_stroke_input() -> void:
	_input_pace = 0.0
	player.ball_aim_marker.visible = false


## Constructs a stroke from player input, determining stroke type based on ball position
func _construct_stroke_from_input(
	closest_step: TrajectoryStep, aim_position: Vector3, pace: float
) -> Stroke:
	if not closest_step:
		push_error("HumanInput._construct_stroke_from_input: closest_step is null")
		return Stroke.new()

	var stroke: Stroke = Stroke.new()
	var to_ball_vector: Vector3 = closest_step.point - player.position
	var dot_product: float = to_ball_vector.dot(player.basis.x)

	if dot_product > 0.0:
		# Forehand stroke
		stroke.stroke_type = Stroke.StrokeType.FOREHAND
		stroke.stroke_power = float(player.stats.get("forehand_pace", 25.0)) + pace
		stroke.stroke_spin = float(player.stats.get("forehand_spin", 5.0))
		stroke.stroke_target = aim_position
	else:
		# Backhand or slice stroke
		if Input.is_action_pressed("slice"):
			stroke.stroke_type = Stroke.StrokeType.BACKHAND_SLICE
			stroke.stroke_power = GameConstants.BACKHAND_SLICE_POWER
			stroke.stroke_spin = GameConstants.BACKHAND_SLICE_SPIN
			stroke.stroke_target = aim_position
		else:
			stroke.stroke_type = Stroke.StrokeType.BACKHAND
			stroke.stroke_power = float(player.stats.get("backhand_pace", 25.0)) + pace
			stroke.stroke_spin = float(player.stats.get("backhand_spin", 5.0))
			stroke.stroke_target = aim_position

	stroke.step = closest_step
	return stroke


## Called when player successfully hits the ball
func _on_player_ball_hit() -> void:
	_move_input_blocked = false
