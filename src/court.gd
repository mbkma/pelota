class_name Court
extends Node3D

var field_width
var field_length

@onready var ne_t_field_overlay = $NE_T_FIELD_Overlay
@onready var nw_t_field_overlay = $NW_T_FIELD_Overlay
@onready var se_t_field_overlay = $SE_T_FIELD_Overlay
@onready var sw_t_field_overlay = $SW_T_FIELD_Overlay


func _ready():
	field_width = $NorthSide/p14.position.x - $NorthSide/p11.position.x
	field_length = $SouthSide/p15.position.z - $NorthSide/p15.position.z
	assert(field_length > 0)
	assert(field_width > 0)


func is_inside(pos: Vector3) -> bool:
	if 2 * abs(pos.z) > field_length or 2 * abs(pos.x) > field_width:
		return false
	else:
		return true


func get_field_at_pos(pos: Vector3) -> int:
	if 2 * abs(pos.z) > field_length or 2 * abs(pos.x) > field_width:
		return GlobalUtils.OUT

	if pos.z > 0:  # South
		if pos.z < $SouthSide/p11.position.z:  #t-field
			if pos.x > $SouthSide/p13.position.x:
				return GlobalUtils.AD_FIELD
			else:
				return GlobalUtils.DEUCE_FIELD
		else:
			return GlobalUtils.S_IN
	else:  # North
		if pos.z > $NorthSide/p11.position.z:  #t-field
			if pos.x > $NorthSide/p13.position.x:
				return GlobalUtils.NE_T_FIELD
			else:
				return GlobalUtils.NW_T_FIELD
		else:
			return GlobalUtils.N_IN
