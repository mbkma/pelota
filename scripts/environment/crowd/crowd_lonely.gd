extends Node3D

@onready var look_at_modifier_3d: LookAtModifier3D = $crowd/Skeleton3D/LookAtModifier3D
@export var n: NodePath
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var idle_animations := [
	"sit-idle-2",
	"sit-idle-3",
	"sit-talk-1",
	"sit-talk-2",
	"sit-talk-3",
]

#func _ready() -> void:
#look_at_modifier_3d.target_node = ^"Camera3D"
