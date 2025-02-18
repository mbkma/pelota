extends Node3D

@onready var look_at_modifier_3d: LookAtModifier3D = $crowd/Skeleton3D/LookAtModifier3D
@export var n: NodePath

#func _ready() -> void:
#look_at_modifier_3d.target_node = ^"Camera3D"
