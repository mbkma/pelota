## Player heads-up display showing stamina and stroke preparation bars
extends Control

@onready var _stamina: TextureProgressBar = $VBoxContainer/Stamina
@onready var _stroke: TextureProgressBar = $VBoxContainer/Stroke

## Reference to player this HUD displays stats for
@export var player: Player

## Whether stamina is currently regenerating
var _regenerates_stamina: bool = false


func _ready() -> void:
	if player:
		player.player_data.stats_changed.connect(_on_player_data_stats_changed)
		player.input_node.pace_changed.connect(_on_player_input_pace_changed)
		player.ball_hit.connect(_on_player_ball_hit)
		_stamina.max_value = float(player.player_data.stats.endurance)


## Setup HUD for singles match (placeholder)
func setup_singles_match(_match_data: Object) -> void:
	pass


## Handle player stats change event, update stamina display
func _on_player_data_stats_changed() -> void:
	_stamina.value = float(player.player_data.stats.endurance)


## Handle input pace change, update stroke bar
func _on_player_input_pace_changed(pace: float) -> void:
	_stroke.value = pace


## Reset stroke bar when player hits ball
func _on_player_ball_hit() -> void:
	_stroke.value = 0.0
