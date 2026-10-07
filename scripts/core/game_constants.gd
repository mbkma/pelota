## Central constants module for all gameplay values
## Consolidates magic numbers and configuration values used across the codebase
class_name GameConstants

# ============================================================================
# PHYSICS CONSTANTS
# ============================================================================

## Gravitational acceleration (m/s²)
const GRAVITY: float = 9.81

# ============================================================================
# INPUT CONSTANTS
# ============================================================================

## Delay before input becomes available after scene load (seconds)
const INPUT_STARTUP_DELAY: float = 0.5

# ============================================================================
# AI CONSTANTS
# ============================================================================

## Forehand spin (x: sidespin, y: topspin, z: forward spin)
const AI_FOREHAND_SPIN: Vector3 = Vector3(0.2, 0.85, 0.0)

## Backhand spin (x: sidespin, y: topspin, z: forward spin)
const AI_BACKHAND_SPIN: Vector3 = Vector3(-0.2, 0.85, 0.0)

## Backhand slice spin (x: sidespin, y: backspin, z: forward spin)
const AI_BACKHAND_SLICE_SPIN: Vector3 = Vector3(-0.3, -0.85, 0.0)

## Drop shot spin (x: sidespin, y: backspin, z: forward spin)
const AI_DROP_SHOT_SPIN: Vector3 = Vector3(0.1, -0.85, 0.0)

## Volley spin (x: sidespin, y: backspin, z: forward spin)
const VOLLEY_SPIN: Vector3 = Vector3(0.0, -0.35, 0.0)

## Drop volley spin (x: sidespin, y: backspin, z: forward spin)
const DROP_VOLLEY_SPIN: Vector3 = Vector3(0.0, -0.8, 0.0)

# ============================================================================
# TIMING CONSTANTS
# ============================================================================

## Delay after a fault before next serve can begin (seconds)
const FAULT_DELAY: float = 1.0

## Additional delay after fault (extends FAULT_DELAY)
const POINT_RESET_EXTRA_DELAY: float = 2.0

# ============================================================================
# TRAJECTORY CONSTANTS
# ============================================================================

## Default number of steps for ball trajectory prediction
const TRAJECTORY_PREDICTION_STEPS: int = 200

## Time step for trajectory prediction (16ms = 1/60th second)
const TRAJECTORY_TIME_STEP: float = 0.016

## Velocity threshold for stopping trajectory prediction (units/sec)
const TRAJECTORY_STOP_VELOCITY_THRESHOLD: float = 0.01

# ============================================================================
# MATCH GAMEPLAY CONSTANTS
# ============================================================================

## Players closer than this to the net (m) volley balls they take before the bounce
const NET_ZONE_DEPTH: float = 6.0

## Minimum ground contacts before counting as double bounce
const GROUND_CONTACT_THRESHOLD: int = 2

# ============================================================================
# COURT CONSTANTS
# ============================================================================

## Singles Court field width half (units)
const COURT_WIDTH_HALF: float = 4.115

## Half court length - baseline distance from net (units)
const COURT_LENGTH_HALF: float = 13.0

## Service Box Length - service line distance from net (units)
const SERVICE_LINE: float = 6.40
