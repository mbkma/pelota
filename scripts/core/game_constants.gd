## Gameplay constants shared across the codebase
class_name GameConstants

## Gravitational acceleration (m/s²)
const GRAVITY: float = 9.81

## Spin per stroke (x: sidespin, y: topspin (+) / backspin (-), z: unused), each in [-1, 1]
const FOREHAND_SPIN: Vector3 = Vector3(0.2, 0.85, 0.0)
const BACKHAND_SPIN: Vector3 = Vector3(-0.2, 0.85, 0.0)
const BACKHAND_SLICE_SPIN: Vector3 = Vector3(-0.3, -0.85, 0.0)
const DROP_SHOT_SPIN: Vector3 = Vector3(0.1, -0.85, 0.0)
const VOLLEY_SPIN: Vector3 = Vector3(0.0, -0.15, 0.0)
const DROP_VOLLEY_SPIN: Vector3 = Vector3(0.0, -0.8, 0.0)

## Volleys are short punches that mostly redirect the incoming pace (see Player): own pace
## (m/s) of a volley and of a drop volley from the weakest to the best volleyer, before the
## redirected pace is added, and the extra pace (m/s) of a high ball put away.
const VOLLEY_PUNCH_SPEED: Vector2 = Vector2(14.0, 18.0)
const DROP_VOLLEY_SPEED: Vector2 = Vector2(5.0, 8.0)
const VOLLEY_PUT_AWAY_PACE: float = 6.0

## Pause (s) after a point before the players walk to their positions for the next one
const POINT_BREAK: float = 3.0

## Default number of steps and time step (s) of a ball trajectory prediction
const TRAJECTORY_PREDICTION_STEPS: int = 200
const TRAJECTORY_TIME_STEP: float = 0.016
## Ball speed (m/s) below which a trajectory prediction stops
const TRAJECTORY_STOP_VELOCITY_THRESHOLD: float = 0.01

## Within this distance of the net (m) players take the ball out of the air instead of letting
## it bounce
const NET_ZONE_DEPTH: float = 6.0
## Players volley from at least this far from the net (m) so the racket stays clear of it
const VOLLEY_MIN_NET_DISTANCE: float = 1.2
## Volley landing depth range (m from the net). A ball at or below the net has to rise over the
## cord, so it can only be played deep (from VOLLEY_DEPTH_LOW_BALL on); a high ball can be put
## away into a short angle (from VOLLEY_DEPTH_MIN on). A neutral aim goes this far (share of the
## half width) toward the open court, away from the opponent.
const VOLLEY_DEPTH_MIN: float = 4.5
const VOLLEY_DEPTH_LOW_BALL: float = 8.5
const VOLLEY_DEPTH_MAX: float = 11.0
const VOLLEY_OPEN_COURT_AIM: float = 0.6

## Half width of the singles court (m)
const COURT_WIDTH_HALF: float = 4.115
## Distance of the baseline from the net (m)
const COURT_LENGTH_HALF: float = 13.0
## Distance of the service line from the net (m)
const SERVICE_LINE: float = 6.40
