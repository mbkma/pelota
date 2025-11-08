class_name PlayerData
extends Resource

signal stats_changed

@export var first_name := ""
@export var last_name := ""
@export var age := 20
@export var country := ""
@export var height := 180
@export var hand := "R"
@export var backhand := 2
@export var rank := 1
@export var stats := {
	"endurance": 100,
	"speed": 100,
	"control": 100,
	"strength": 100,
	"serve_pace": 35,
	"forehand_pace": 25,
	"forehand_spin": 5,
	"backhand_pace": 25,
	"backhand_spin": 5,
}
@export var sounds := {
	"grunt_flat": [],
	"grunt_frequency": 0.0,
	"victory": [],
}


func set_stat(stat, value):
	stats[stat] = value
	emit_signal("stats_changed")

#func to_string():
#return first_name+last_name+country
