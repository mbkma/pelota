extends Control

@onready var stamina: TextureProgressBar = $VBoxContainer/Stamina
@onready var stroke: TextureProgressBar = $VBoxContainer/Stroke
#@onready var drawing := Drawing.new()

var player: BasePlayer
var regenerates_stamina := false

#func _process(delta: float) -> void:
#drawing.clear()
#drawing.drawline(Vector3(0,1,0), Vector3(4,4+randf_range(0,10),10))


func setup_singles_match(sm: SinglesMatch):
	player = sm.players[0]
	player.player_data.connect("stats_changed", Callable(self, "_on_PlayerData_stats_changed"))
	player.input.connect("pace_changed", Callable(self, "_on_PlayerInput_pace_changed"))
	player.connect("ball_hit", Callable(self, "_on_Player_ball_hit"))
	sm.connect("state_changed", Callable(self, "on_sm_state_changed"))
	stamina.max_value = player.player_data.stats.endurance
	#add_child(drawing)


#	set_process(true)


func _on_PlayerData_stats_changed():
	stamina.value = player.player_data.stats.endurance


func _on_PlayerInput_pace_changed(pace):
	stroke.value = pace


func on_sm_state_changed(old_state, new_state):
	if new_state == GlobalUtils.MatchStates.IDLE:
		stroke.value = 0


func _on_Player_ball_hit():
	stroke.value = 0
