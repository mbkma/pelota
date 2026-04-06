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
		_connect_controller_signals()
		player.ball_hit.connect(_on_player_ball_hit)
		_stamina.max_value = float(player.player_data.stats.endurance)


func _connect_controller_signals() -> void:
	if not player:
		return

	if player.controller and player.controller.has_signal("pace_changed"):
		var on_pace_changed := Callable(self, "_on_player_input_pace_changed")
		if not player.controller.is_connected("pace_changed", on_pace_changed):
			player.controller.connect("pace_changed", on_pace_changed)
		return

	# Player may still be initializing its controller during this frame.
	call_deferred("_connect_controller_signals")


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
