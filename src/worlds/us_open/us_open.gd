class_name USOpen
extends Node3D

@onready var television: Television = $Television as Television
@onready var stadium = $Stadium as Stadium
@onready var umpire = stadium.get_node("Umpire")
@onready var court: Court = stadium.get_node("Court") as Court
@onready var ball_aim_human: MeshInstance3D = $BallAimHuman
@onready var ball_mark: MeshInstance3D = $BallMark
@onready var challenge_cam: Camera3D = $ChallengeCam
@onready var hud: Control = $Hud


var current_match: SinglesMatch


func setup_singles_match(sm: SinglesMatch):
	current_match = sm
	stadium.setup_singles_match(sm)
	$Stadium/Umpire.setup_singles_match(sm)
	$Crowd.setup_singles_match(sm)
	$DebugHud.setup_singles_match(sm)
	hud.setup_singles_match(sm)
	television.setup_singles_match(sm)
	television.start_broadcast()
	for player in sm.players:
		player.ball_hit.connect(_on_Player_ball_hit)
		player.challenged.connect(_on_Player_challenged)
	stadium.start_serve_clocks()

func _on_Player_challenged():
	await get_tree().create_timer(2).timeout
	ball_mark.position = current_match.last_ball_ground_pos
	challenge_cam.position = current_match.last_ball_ground_pos
	challenge_cam.position.y += 1
	ball_mark.visible = true
	challenge_cam.current = true
	await get_tree().create_timer(5).timeout
	ball_mark.visible = false
	television.active_camera.current = true


func _on_Player_ball_hit():
	var pred = GlobalPhysics.get_ball_position_at_ground(current_match._active_ball)
	ball_mark.position = pred.pos
	ball_mark.visible = true
	await get_tree().create_timer(2).timeout
	ball_mark.visible = false


func get_stadium_position(string):
	return stadium.positions[string]
