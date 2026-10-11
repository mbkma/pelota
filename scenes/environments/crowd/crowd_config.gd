@tool
class_name CrowdConfig
extends Resource
## Who sits in the stands and how.

## Share of the seats that are taken
@export_range(0.0, 1.0, 0.01) var occupancy: float = 0.9:
	set(value):
		occupancy = value
		emit_changed()

## Spectators the seats are filled with, picked at random
@export var characters: Array[CrowdCharacter] = []:
	set(value):
		characters = value
		emit_changed()

## Where a spectator stands relative to their seat's transform (m, +Z towards the court)
@export var seat_offset: Vector3 = Vector3.ZERO:
	set(value):
		seat_offset = value
		emit_changed()

## How differently spectators sit: sideways shift in the seat (m), turn (degrees) and size
## (share, both ways)
@export var seat_jitter: float = 0.04
@export var turn_jitter_degrees: float = 10.0
@export var size_jitter: float = 0.05
