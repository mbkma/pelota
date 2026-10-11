## The stadium: court, player start positions, serve clocks, serve speed and match time panels,
## the player benches with their spare rackets, the courtside TV cameras (one on each player, one
## on the ball) and the match cameras.
class_name Stadium
extends Node3D

enum StadiumPosition {
	SERVE_FRONT_RIGHT,
	SERVE_FRONT_LEFT,
	RECEIVE_FRONT_RIGHT,
	RECEIVE_FRONT_LEFT,
	SERVE_BACK_RIGHT,
	SERVE_BACK_LEFT,
	RECEIVE_BACK_RIGHT,
	RECEIVE_BACK_LEFT
}

## Seconds the server has between points
const SERVE_CLOCK_SECONDS: float = 25.0

@onready var positions: Dictionary[StadiumPosition, Vector3] = {
	StadiumPosition.SERVE_FRONT_RIGHT: $Positions/ServeFrontRight.position,
	StadiumPosition.SERVE_FRONT_LEFT: $Positions/ServeFrontLeft.position,
	StadiumPosition.RECEIVE_FRONT_RIGHT: $Positions/ReceiveFrontRight.position,
	StadiumPosition.RECEIVE_FRONT_LEFT: $Positions/ReceiveFrontLeft.position,
	StadiumPosition.SERVE_BACK_RIGHT: $Positions/ServeBackRight.position,
	StadiumPosition.SERVE_BACK_LEFT: $Positions/ServeBackLeft.position,
	StadiumPosition.RECEIVE_BACK_RIGHT: $Positions/ReceiveBackRight.position,
	StadiumPosition.RECEIVE_BACK_LEFT: $Positions/ReceiveBackLeft.position
}

@onready var _serve_speed_panels: Array[ServeSpeedPanel] = [$ServeSpeedPanel, $ServeSpeedPanel2]
@onready var _serve_clocks: Array[Node] = $ServeClocks.get_children()
@onready var _serve_clock_timer: Timer = $ServeClockTimer
@onready var _time_label: Label3D = $RolexClock/Time
@onready var _front_player_camera: TargetTracker = $FrontPlayerCamera
@onready var _back_player_camera: TargetTracker = $BackPlayerCamera
@onready var _ball_camera: TargetTracker = $BallCamera
@onready
var _bench_rackets: Array[Array] = [$Player1Bench.get_children(), $Player2Bench.get_children()]


func _ready() -> void:
	_serve_clock_timer.timeout.connect(stop_serve_clocks)
	set_process(false)


func _process(_delta: float) -> void:
	for clock: ServeClock in _serve_clocks:
		clock.show_seconds(int(_serve_clock_timer.time_left))


func show_serve_speed(ball: Ball) -> void:
	for panel in _serve_speed_panels:
		panel.show_serve_speed(ball.velocity.length())


## Shows the match time as hours:minutes on the Rolex clock.
func show_match_time(elapsed_seconds: float) -> void:
	var total_minutes: int = floori(elapsed_seconds / 60.0)
	_time_label.text = "%d:%02d" % [floori(total_minutes / 60.0), total_minutes % 60]


## Points the courtside TV cameras at the player on their end of the court.
func track_players(front_player: Player, back_player: Player) -> void:
	_front_player_camera.target = front_player
	_back_player_camera.target = back_player


## Points the courtside ball camera at `target`: the ball during a point, the server between
## points.
func aim_ball_camera(target: Node3D) -> void:
	_ball_camera.target = target


## Gives the rackets on each player's bench the player's racket look (`players` in team order).
func show_bench_rackets(players: Array[Player]) -> void:
	for i in players.size():
		for racket: Racket in _bench_rackets[i]:
			racket.show_appearance(players[i].model.appearance)


func start_serve_clocks() -> void:
	_set_serve_clocks_visible(true)
	_serve_clock_timer.start(SERVE_CLOCK_SECONDS)


func stop_serve_clocks() -> void:
	_set_serve_clocks_visible(false)
	_serve_clock_timer.stop()


func _set_serve_clocks_visible(clocks_visible: bool) -> void:
	for clock: ServeClock in _serve_clocks:
		clock.set_running(clocks_visible)
	set_process(clocks_visible)
