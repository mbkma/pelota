## Human player input handler for keyboard/mouse controls
## Manages movement, aiming, and stroke execution
class_name HumanController
extends Controller

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
	# Handle stroke input
	if not _stroke_input_blocked:
		var is_any_action_pressed: bool = (
			Input.is_action_pressed("strike") or
			Input.is_action_pressed("slice") or
			Input.is_action_pressed("drop_shot")
		)

		var is_any_action_just_pressed: bool = (
			Input.is_action_just_pressed("strike") or
			Input.is_action_just_pressed("slice") or
			Input.is_action_just_pressed("drop_shot")
		)

		var is_any_action_just_released: bool = (
			Input.is_action_just_released("strike") or
			Input.is_action_just_released("slice") or
			Input.is_action_just_released("drop_shot")
		)

		# Initialize stroke when button is first pressed
		if is_any_action_just_pressed:
			_input_pace = 0.0
			_mouse_from = get_viewport().get_mouse_position()
			_aiming_at = _get_default_aim()

		# Continuously update aim and pace while button is held
		if is_any_action_pressed:
			_input_pace += GameConstants.PACE_INCREMENT_RATE
			_input_pace = clamp(_input_pace, 0.0, 1.0)  # Cap pace at 100%
			pace_changed.emit(_input_pace)
			_mouse_to = get_viewport().get_mouse_position()
			_aiming_at = _get_aim_pos(_mouse_from, _mouse_to)
			print("aiming at, ", _aiming_at)
			player.ball_aim_marker.global_position = _aiming_at
			player.ball_aim_marker.visible = true
			# Scale marker based on pace for visual feedback (1.0 - 1.5x size)
			player.ball_aim_marker.scale = Vector3.ONE * (1.0 + _input_pace * 0.5)

		# Execute stroke when button is released
		if is_any_action_just_released:
			# Determine which stroke type was used
			var stroke_type: String = "topspin"
			if Input.is_action_just_released("slice"):
				stroke_type = "slice"
			elif Input.is_action_just_released("drop_shot"):
				stroke_type = "drop_shot"

			if Input.is_action_just_released("strike") and _serve_controls:
				_do_serve(_aiming_at, _input_pace)
				_serve_controls = false
			else:
				_do_stroke(_aiming_at, _input_pace, stroke_type)

	# Handle challenge input
	if Input.is_action_just_pressed("challenge"):
		player.challenge()
		_vibrate_joypad(0.7, 0.2)  # Strong short vibration on challenge


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
	stroke.stroke_power = GameConstants.AI_SERVE_PACE + pace
	stroke.stroke_spin = GameConstants.AI_SERVE_SPIN
	stroke.stroke_target = aim_position

	player.serve(stroke)


## Executes a rally stroke (forehand/backhand/slice)
func _do_stroke(aim_position: Vector3, pace: float, stroke_name := "topspin") -> void:
	if not validate_player():
		push_error("HumanInput._do_stroke: Invalid player state")
		_move_input_blocked = false
		return

	if not player.ball:
		push_error("HumanInput._do_stroke: Player has no ball to stroke")
		_move_input_blocked = false
		return

	var closest_step: TrajectoryStep = get_closest_trajectory_step(player)
	if not closest_step:
		push_error("HumanInput._do_stroke: Could not find ball trajectory step")
		_move_input_blocked = false
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
		_move_input_blocked = false
		return

	var stroke: Stroke = _construct_stroke_from_input(closest_step, aim_position, pace, stroke_name)
	_move_input_blocked = true

	player.queue_stroke(stroke)
	adjust_player_position_to_stroke(player, closest_step)

	_clear_stroke_input()


## Clears stroke input state after executing a stroke
func _clear_stroke_input() -> void:
	_input_pace = 0.0
	player.ball_aim_marker.visible = false


## Constructs a stroke from player input, determining stroke type based on ball position
func _construct_stroke_from_input(
	closest_step: TrajectoryStep, aim_position: Vector3, pace: float, stroke_name: String
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
		stroke.stroke_power = GameConstants.AI_FOREHAND_PACE + pace
		stroke.stroke_spin = GameConstants.AI_FOREHAND_SPIN
		stroke.stroke_target = aim_position
	else:
		# Backhand or slice stroke
		if stroke_name == "slice":
			stroke.stroke_type = Stroke.StrokeType.BACKHAND_SLICE
			stroke.stroke_power = GameConstants.AI_BACKHAND_SLICE_PACE
			stroke.stroke_spin = GameConstants.AI_BACKHAND_SLICE_SPIN
			stroke.stroke_target = aim_position
		elif stroke_name == "drop_shot":
			stroke.stroke_type = Stroke.StrokeType.BACKHAND_DROP_SHOT
			stroke.stroke_power = GameConstants.AI_DROP_SHOT_PACE
			stroke.stroke_spin = GameConstants.AI_DROP_SHOT_SPIN
			stroke.stroke_target = aim_position
		else:
			stroke.stroke_type = Stroke.StrokeType.BACKHAND
			stroke.stroke_power = GameConstants.AI_BACKHAND_PACE + pace
			stroke.stroke_spin = GameConstants.AI_BACKHAND_SPIN
			stroke.stroke_target = aim_position

	stroke.step = closest_step
	return stroke


## Called when player successfully hits the ball
func _on_player_ball_hit() -> void:
	_move_input_blocked = false
	_vibrate_joypad(0.8, 0.1)  # Strong brief vibration on ball contact


## Vibrates the joypad with specified strength and duration
func _vibrate_joypad(strength: float, duration: float) -> void:
	strength = clamp(strength, 0.0, 1.0)

	# Get the first connected joypad
	var joypad_id: int = 0
	if Input.get_connected_joypads().size() > 0:
		joypad_id = Input.get_connected_joypads()[0]
	else:
		return  # No joypad connected

	# Strong vibration (left motor) and weak vibration (right motor)
	Input.start_joy_vibration(joypad_id, strength * 0.8, strength * 0.5, duration)
