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
## Simple execution skill model (0-100) used to perturb intended strokes.
@export var stats := {
	"execution_consistency": 75,
	"target_precision": 75,
	"power_precision": 75,
	"spin_precision": 75,
}
@export var sounds := {
	"grunt_flat": [],
	"grunt_frequency": 0.0,
	"victory": [],
}

#func to_string():
#return first_name+last_name+country
