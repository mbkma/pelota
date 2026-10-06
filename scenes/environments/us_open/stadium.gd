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

var serve_clocks_active := false
var timer := Timer.new()


@onready var serve_speed_panels := [$ServeSpeedPanel, $ServeSpeedPanel2]

@onready var positions := {
	StadiumPosition.SERVE_FRONT_RIGHT: $Positions/ServeFrontRight.position,
	StadiumPosition.SERVE_FRONT_LEFT: $Positions/ServeFrontLeft.position,
	StadiumPosition.RECEIVE_FRONT_RIGHT: $Positions/ReceiveFrontRight.position,
	StadiumPosition.RECEIVE_FRONT_LEFT: $Positions/ReceiveFrontLeft.position,
	StadiumPosition.SERVE_BACK_RIGHT: $Positions/ServeBackRight.position,
	StadiumPosition.SERVE_BACK_LEFT: $Positions/ServeBackLeft.position,
	StadiumPosition.RECEIVE_BACK_RIGHT: $Positions/ReceiveBackRight.position,
	StadiumPosition.RECEIVE_BACK_LEFT: $Positions/ReceiveBackLeft.position
}

@onready var serve_clocks := $ServeClocks.get_children()
@onready var _time_label: Label3D = $TimePanel/Label3D
@onready var _front_player_camera: TargetTracker = $FrontPlayerCamera
@onready var _back_player_camera: TargetTracker = $BackPlayerCamera

func _ready() -> void:
	add_child(timer)
	timer.timeout.connect(_on_ServeClocks_timeout)


func _process(_delta: float) -> void:
	if serve_clocks_active:
		for clock in serve_clocks:
			clock.text = str(int(timer.get_time_left())) + "\n" + "Serve Clock"


func show_serve_speed(ball: Ball):
	for panel in serve_speed_panels:
		panel.show_serve_speed(ball.velocity.length())


## Shows the match time as hours:minutes on the time panel.
func show_match_time(elapsed_seconds: float) -> void:
	var total_minutes: int = floori(elapsed_seconds / 60.0)
	_time_label.text = "%d:%02d" % [floori(total_minutes / 60.0), total_minutes % 60]


## Points the courtside TV cameras at the player on their end of the court.
func track_players(front_player: Player, back_player: Player) -> void:
	_front_player_camera.target = front_player
	_back_player_camera.target = back_player


func get_stadium_position(pos: String):
	return positions[pos]


func start_serve_clocks():
	for clock in serve_clocks:
		clock.visible = true
	timer.wait_time = 25
	timer.start()
	serve_clocks_active = true


func stop_serve_clocks():
	for clock in serve_clocks:
		clock.visible = false
	serve_clocks_active = false


func _on_ServeClocks_timeout():
	stop_serve_clocks()
