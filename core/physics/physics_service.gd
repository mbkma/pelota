## Global physics calculations and utilities for ball mechanics
extends Node

## Ball damping factor (energy retention per bounce)
const BALL_DAMP: float = 0.7

## Gravitational acceleration (m/s²)
const GRAVITY: float = 9.81




## Converts ball spin value to gravity effect
## Higher spin values increase downward gravity acceleration
func _spin_to_gravity(spin: float) -> float:
	return spin * GameConstants.SPIN_GRAVITY_MULTIPLIER
