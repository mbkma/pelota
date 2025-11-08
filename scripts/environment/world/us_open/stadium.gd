class_name Stadium
extends Node3D

@onready var serve_speed_panels := [$ServeSpeedPanel, $ServeSpeedPanel2]

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

@onready var player_camera: Node3D = $PlayerCamera
@onready var back_player_camera: Node3D = $BackPlayerCamera
@onready var front_player_camera: Node3D = $FrontPlayerCamera

var serve_clocks_active := false
var timer := Timer.new()


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
