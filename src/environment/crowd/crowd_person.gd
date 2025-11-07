class_name CrowdPerson
extends Node3D

@export var people := {
	"crowd-1": preload("res://assets/models/crowd/crowd-1.blend"),
	"crowd-2": preload("res://assets/models/crowd/crowd-2.blend"),
	"crowd-3": preload("res://assets/models/crowd/crowd-3.blend"),
	"crowd-4": preload("res://assets/models/crowd/crowd-4.blend"),
}

var idle_animations := [
	"sit-idle-2",
	"sit-idle-3",
	"sit-talk-1",
	"sit-talk-2",
	"sit-talk-3",
]

var victory_animations := [
	"sit-victory-1",
	"sit-victory-2",
	"sit-victory-3",
	"sit-victory-4",
]

var animation_player: AnimationPlayer
@export var key := "crowd-1"


func _ready() -> void:
	var person = people[key].instantiate()
	add_child(person)
	animation_player = get_node(key + "/AnimationPlayer")
