## Gameplay constants shared across the codebase
class_name GameConstants

## Gravitational acceleration (m/s²)
const GRAVITY: float = 9.81

## Spin per stroke (x: sidespin, y: topspin (+) / backspin (-), z: unused), each in [-1, 1]
const FOREHAND_SPIN: Vector3 = Vector3(0.2, 0.85, 0.0)
const BACKHAND_SPIN: Vector3 = Vector3(-0.2, 0.85, 0.0)
const BACKHAND_SLICE_SPIN: Vector3 = Vector3(-0.3, -0.85, 0.0)
const DROP_SHOT_SPIN: Vector3 = Vector3(0.1, -0.85, 0.0)
const VOLLEY_SPIN: Vector3 = Vector3(0.0, -0.35, 0.0)
const DROP_VOLLEY_SPIN: Vector3 = Vector3(0.0, -0.8, 0.0)

## Pause (s) after a point before the players walk to their positions for the next one
const POINT_BREAK: float = 3.0

## Default number of steps and time step (s) of a ball trajectory prediction
const TRAJECTORY_PREDICTION_STEPS: int = 200
const TRAJECTORY_TIME_STEP: float = 0.016
## Ball speed (m/s) below which a trajectory prediction stops
const TRAJECTORY_STOP_VELOCITY_THRESHOLD: float = 0.01

## Players closer than this to the net (m) volley balls they take before the bounce
const NET_ZONE_DEPTH: float = 6.0

## Half width of the singles court (m)
const COURT_WIDTH_HALF: float = 4.115
## Distance of the baseline from the net (m)
const COURT_LENGTH_HALF: float = 13.0
## Distance of the service line from the net (m)
const SERVICE_LINE: float = 6.40
