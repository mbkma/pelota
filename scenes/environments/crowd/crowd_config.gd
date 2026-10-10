@tool
class_name CrowdConfig
extends Resource
## Layout and spectators of a crowd block.

## Rows and columns of seats in the block
@export var grid_rows: int = 10:
	set(value):
		grid_rows = value
		emit_changed()
@export var grid_columns: int = 4:
	set(value):
		grid_columns = value
		emit_changed()

## Seat spacing (m): sideways (x), up per row (y), back per row (z)
@export var seat_spacing: Vector3 = Vector3(0.7, 0.29, 1.029):
	set(value):
		seat_spacing = value
		emit_changed()

## Share of the seats that are taken
@export_range(0.0, 1.0, 0.01) var occupancy: float = 0.92:
	set(value):
		occupancy = value
		emit_changed()

## Spectators the seats are filled with, picked at random
@export var characters: Array[CrowdCharacter] = []:
	set(value):
		characters = value
		emit_changed()

## How differently spectators sit: sideways shift in the seat (m), turn (degrees) and size
## (share, both ways)
@export var seat_jitter: float = 0.06
@export var turn_jitter_degrees: float = 10.0
@export var size_jitter: float = 0.05
