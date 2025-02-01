class_name Stadium
extends Node3D

@onready var serve_speed_panels := [$ServeSpeedPanel, $ServeSpeedPanel2]
var sm
@onready var positions := {
		"serve_deuce0": $Positions/ServeDeuce0.position,
		"serve_ad0": $Positions/ServeAd0.position,
		"receive_deuce0": $Positions/ReceiveDeuce0.position,
		"receive_ad0": $Positions/ReceiveAd0.position,
		"serve_deuce1": $Positions/ServeDeuce1.position,
		"serve_ad1": $Positions/ServeAd1.position,
		"receive_deuce1": $Positions/ReceiveDeuce1.position,
		"receive_ad1": $Positions/ReceiveAd1.position,
}
@onready var serve_clocks := $ServeClocks.get_children()

var serve_clocks_active := false
var timer := Timer.new()


func _ready() -> void:
	add_child(timer)
	timer.timeout.connect(_on_ServeClocks_timeout)

func setup_singles_match(singles_match):
	sm = singles_match
	for player in sm.players:
		player.just_served.connect(_on_Player_just_served)


func _process(delta: float) -> void:
	if serve_clocks_active:
		for clock in serve_clocks:
			clock.text = str(int(timer.get_time_left())) + "\n" + "Serve Clock"


func _on_Player_just_served():
	for panel in serve_speed_panels:
		panel.show_serve_speed(sm._active_ball.velocity.length())
	stop_serve_clocks()


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
