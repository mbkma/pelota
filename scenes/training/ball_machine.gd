## Ball machine on the far baseline: shoots rally balls that bounce in front of a player, a
## little to either side so the player has to move to them. A player at the net gets the ball
## out of the air.
class_name BallMachine
extends Node3D

## Bounces stay this far inside the lines (m).
const LINE_MARGIN: float = 0.3
## Height (m) by which the balls pass over the net cord
const NET_CLEARANCE: float = 0.4

## Ball speed (m/s) drawn per ball: ~65-85 km/h, a rally ball from the back of the court.
@export var ball_speed: Vector2 = Vector2(18.0, 24.0)
## Spin of the balls (x: sidespin, y: topspin (+) / backspin (-)), each in [-1, 1]
@export var ball_spin: Vector3 = Vector3(0.0, 0.5, 0.0)
## Farthest the bounce lands to either side of the player (m)
@export var lateral_spread: float = 2.5
## How far in front of the player the ball bounces (m), so it comes up to a comfortable height
@export var bounce_ahead: float = 4.5
## Ball scene shot by the machine
@export var ball_scene: PackedScene

@onready var _muzzle: Marker3D = $Muzzle


## Shoots a ball toward `player` and returns it. The ball is added next to the machine.
func shoot_at(player: Player) -> Ball:
	var player_side: float = signf(player.global_position.z)
	var depth: float = clampf(
		absf(player.global_position.z) - bounce_ahead,
		GameConstants.SERVICE_LINE - 1.0,
		GameConstants.COURT_LENGTH_HALF - LINE_MARGIN
	)
	var lateral_limit: float = GameConstants.COURT_WIDTH_HALF - LINE_MARGIN
	var lateral: float = clampf(
		player.global_position.x + randf_range(-lateral_spread, lateral_spread),
		-lateral_limit,
		lateral_limit
	)
	var target := Vector3(lateral, 0.0, depth * player_side)
	look_at(Vector3(target.x, global_position.y, target.z))

	var ball: Ball = ball_scene.instantiate()
	ball.initial_position = _muzzle.global_position
	ball.spin = ball_spin
	ball.initial_velocity = ball.calculate_velocity(
		ball.initial_position,
		target,
		player_side * randf_range(ball_speed.x, ball_speed.y),
		ball_spin,
		NET_CLEARANCE
	)
	get_parent().add_child(ball)
	return ball
