class_name StadiumTier
extends RefCounted
## A tier of a stadium's stands: rows of seats, rising row by row (see ArthurAsheBuilder).

var name: String
## Offset (m) of the first row's front and depth of a row
var front: float
var depth: float
var rows: int
## Floor height (m) of the first row, rise to the second row and how much the rise grows
## with every row (stands get steeper towards the back)
var height: float
var rise: float
var rise_growth: float
## Floor height behind the last row
var top: float
## Whether the rows are split into sections by aisles (else into suites by partitions)
var has_aisles: bool


func _init(
	tier_name: String,
	tier_front: float,
	row_depth: float,
	row_count: int,
	first_height: float,
	first_rise: float,
	growth: float,
	top_height: float,
	aisles: bool
) -> void:
	name = tier_name
	front = tier_front
	depth = row_depth
	rows = row_count
	height = first_height
	rise = first_rise
	rise_growth = growth
	top = top_height
	has_aisles = aisles


func row_front(row: int) -> float:
	return front + row * depth


## Floor height of `row`; the row after the last is the floor behind the tier.
func row_height(row: int) -> float:
	if row >= rows:
		return top
	return height + rise * row + rise_growth * row * (row - 1) * 0.5


func back() -> float:
	return front + rows * depth


func middle() -> float:
	return front + rows * depth * 0.5
