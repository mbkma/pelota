extends Node

signal level_changed(level_name, init_data)

@onready var world = $TrainingCenter
@onready var court: Court = world.court

var _active_ball = null

# sides / directions
var players: Array


func init_scene(init_data: Dictionary):
	var match_data = init_data.match_data as MatchData
	players.append(GlobalGameData.create_player(match_data.player0, false))
	players.append(GlobalGameData.create_player(match_data.player1, true))
	for player in players:
		add_child(player)
		player.setup_training(self)
		#player.ball_spawned.connect(on_Player_ball_spawned)

	players[0].camera = world.player_cameras[0]
	players[1].camera = world.player_cameras[1]
	players[0].position = world.spawn_positions[0].position
	players[1].position = world.spawn_positions[1].position

	players[0].is_serving = true


#	world.setup_training(self)
func _process(delta: float) -> void:
	pass
