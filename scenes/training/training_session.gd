## Root of a training: one human player on court and a ball machine on the far baseline. The
## player moves and plays freely; `request_ball` (E / right trigger) shoots the next ball. The
## HUD shows where the player's last shot went and how fast it was. Run directly, the player set
## in the scene trains with the keyboard.
class_name TrainingSession
extends PlaySession

## Seconds a ball stays on court after it was shot
const BALL_LIFETIME: float = 8.0
const RESULT_COLOR_IN := Palette.TEAL_LIGHT
const RESULT_COLOR_MISS := Palette.RED_LIGHT

@export var player: Player
@export var ball_machine: BallMachine
@export var stadium: Stadium
@export var court: Court
@export var cameras: MatchCameras
## Shows where the player's last shot went
@export var shot_result_label: Label

## Ball the player hit last, until it lands or runs into the net
var _hit_ball: Ball
## Speed (km/h) the player hit that ball with
var _hit_speed_kmh: float = 0.0


func _enter_tree() -> void:
	# The menu music stops when the training begins (no music director when run directly).
	var music_director: MusicDirector = get_tree().root.get_node_or_null(^"MusicDirector")
	if music_director:
		music_director.stop()

	if GlobalGameData.selected_training_player:
		player.player_data = GlobalGameData.selected_training_player
	if not GlobalGameData.is_human_controlled(player.team_index):
		GlobalGameData.set_match_input_devices(KeyboardInput.DEVICE_ID, InputDevice.NO_DEVICE_ID)


func _ready() -> void:
	player.session = self
	player.ball_hit.connect(_on_player_ball_hit)
	stadium.show_bench_rackets([player])
	cameras.register_camera(player.first_person_camera)
	cameras.show_from_behind(player)
	shot_result_label.text = ""


func _process(_delta: float) -> void:
	# Polled rather than read from input events: a trigger sends a stream of motion events while
	# it is pulled, each of them "pressed".
	if Input.is_action_just_pressed(&"request_ball"):
		_shoot_ball()


func is_return_of_serve(_player: Player) -> bool:
	return false


func is_second_serve() -> bool:
	return false


## The ball machine stands in for the opponent.
func get_opponent_position(_player: Player) -> Vector3:
	return ball_machine.global_position


## Shoots the next ball at the player; it replaces the ball the player tracks.
func _shoot_ball() -> void:
	var ball: Ball = ball_machine.shoot_at(player)
	player.set_active_ball(ball)
	get_tree().create_timer(BALL_LIFETIME, false).timeout.connect(_remove_ball.bind(ball))


func _remove_ball(ball: Ball) -> void:
	if player.ball == ball:
		player.set_active_ball(null)
	if _hit_ball == ball:
		_hit_ball = null
	ball.queue_free()


func _on_player_ball_hit() -> void:
	if _hit_ball:
		_stop_tracking_hit_ball()
	_hit_ball = player.ball
	_hit_speed_kmh = _hit_ball.velocity.length() * 3.6
	_hit_ball.on_ground.connect(_on_hit_ball_landed)
	_hit_ball.on_net.connect(_on_hit_ball_in_net)


func _stop_tracking_hit_ball() -> void:
	_hit_ball.on_ground.disconnect(_on_hit_ball_landed)
	_hit_ball.on_net.disconnect(_on_hit_ball_in_net)
	_hit_ball = null


## The first bounce of the player's shot decides whether it was in.
func _on_hit_ball_landed() -> void:
	var target_half: Court.CourtRegion = (
		Court.CourtRegion.FRONT_SINGLES_BOX
		if ball_machine.global_position.z > 0.0
		else Court.CourtRegion.BACK_SINGLES_BOX
	)
	var is_in: bool = court.is_ball_in_court_region(_hit_ball.global_position, target_half)
	_show_shot_result(
		"%s  %d km/h" % ["IN" if is_in else "OUT", roundi(_hit_speed_kmh)],
		RESULT_COLOR_IN if is_in else RESULT_COLOR_MISS
	)
	_stop_tracking_hit_ball()


func _on_hit_ball_in_net() -> void:
	_show_shot_result("NET", RESULT_COLOR_MISS)
	_stop_tracking_hit_ball()


func _show_shot_result(text: String, color: Color) -> void:
	shot_result_label.text = text
	shot_result_label.add_theme_color_override("font_color", color)
