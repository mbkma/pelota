## Central constants module for all gameplay values
## Consolidates magic numbers and configuration values used across the codebase
class_name GameConstants

# ============================================================================
# PHYSICS CONSTANTS
# ============================================================================

## Gravitational acceleration (m/s²)
const GRAVITY: float = 9.81

## Ball damping factor (0.0-1.0, 0.7 means 30% energy loss per bounce)
const BALL_DAMP: float = 0.8

## Ball ground contact threshold (distance in meters)
const BALL_GROUND_THRESHOLD: float = 0.035

## Spin-to-gravity conversion multiplier for ball physics
const SPIN_GRAVITY_MULTIPLIER: float = 0.5

## Air resistance/friction factor for velocity damping
const AIR_RESISTANCE_FACTOR: float = 0.001

## Net bounce velocity damping (X and Z reduction factor)
const NET_BOUNCE_VELOCITY_DAMPING: float = 0.1

## Ground level threshold for emit signal (units)
const GROUND_EMISSION_THRESHOLD: float = 0.1

## Velocity magnitude threshold for trajectory tracking (units/sec)
const VELOCITY_TRACKING_THRESHOLD: float = 0.1


# ============================================================================
# PLAYER CONSTANTS
# ============================================================================

## Default player movement speed (units/sec)
const PLAYER_MOVE_SPEED: float = 5.0

## Player acceleration factor for movement interpolation
const PLAYER_ACCELERATION: float = 0.1

## Player friction factor for deceleration
const PLAYER_FRICTION: float = 1.0

## Distance threshold for path navigation (units)
const PLAYER_DISTANCE_THRESHOLD: float = 0.01

# ============================================================================
# INPUT CONSTANTS
# ============================================================================

## Mouse sensitivity multiplier for stroke aiming
const MOUSE_SENSITIVITY: float = 100.0

## Delay before input becomes available after scene load (seconds)
const INPUT_STARTUP_DELAY: float = 0.5

## Default aim position multiplier for front court strokes
const AIM_FRONT_COURT: float = 9.0

## Default aim position multiplier for back court strokes
const AIM_BACK_COURT: float = 3.0

## Default aim position multiplier for serves
const AIM_SERVE: float = 5.0

## Pace increment rate per input frame
const PACE_INCREMENT_RATE: float = 0.1

## Ball velocity threshold for canceling stroke (units/sec)
const BALL_VELOCITY_CANCELLATION_THRESHOLD: float = 0.1


## Animation hit time as proportion of animation (forehand default)
const ANIMATION_HIT_TIME: float = 0.63

# ============================================================================
# AI CONSTANTS
# ============================================================================

## Standard stroke target distance for baseline shots
const AI_STROKE_STANDARD_LENGTH: float = 10.0

## Cross-court target offset from center
const AI_STROKE_CROSS_OFFSET: float = 3.0

## Drop shot target distance
const AI_STROKE_DROP_DISTANCE: float = 4.0

## Serve target distance
const AI_SERVE_DISTANCE: float = 5.0

## Minimum distance to ball before AI commits to stroke
const AI_BALL_COMMIT_DISTANCE: float = 3.0

## AI ball velocity minimum before considering it "stopped"
const AI_BALL_VELOCITY_MIN: float = 0.1

## Forehand pace (power)
const AI_FOREHAND_PACE: float = 25.0

## Forehand spin
const AI_FOREHAND_SPIN: float = 1.0

## Backhand pace (power)
const AI_BACKHAND_PACE: float = 22.0

## Backhand spin
const AI_BACKHAND_SPIN: float = 0.5

## Backhand slice pace (power)
const AI_BACKHAND_SLICE_PACE: float = 18.0

## Backhand slice spin
const AI_BACKHAND_SLICE_SPIN: float = -1.0

## Drop shot pace (power)
const AI_DROP_SHOT_PACE: float = 10.0

## Drop shot spin
const AI_DROP_SHOT_SPIN: float = -1.0

## Serve pace (power)
const AI_SERVE_PACE: float = 30.0

## Serve spin
const AI_SERVE_SPIN: float = 0.8

# ============================================================================
# TIMING CONSTANTS
# ============================================================================

## Delay after a fault before next serve can begin (seconds)
const FAULT_DELAY: float = 1.0

## Delay after point ends before positioning for next point (seconds)
const POINT_RESET_DELAY: float = 3.0

## Delay before AI initiates serve after request (seconds)
const AI_SERVE_STARTUP_DELAY: float = 2.0

## Animation frame sync delay for physics operations (seconds)
const PHYSICS_FRAME_SYNC_DELAY: float = 0.05

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

## Minimum ground contacts before counting as double bounce
const GROUND_CONTACT_THRESHOLD: int = 2

## Game cycle for side switching (every 4th game)
const SIDE_SWITCH_GAME_CYCLE: int = 4

# ============================================================================
# COURT CONSTANTS
# ============================================================================

## Court field width (units)
const COURT_WIDTH: float = 8.11

## Court field length (units)
const COURT_LENGTH: float = 26.0

## Half court length - baseline distance from net (units)
const COURT_LENGTH_HALF: float = 13.0

# ============================================================================
# PLAYER POSITIONS
# ============================================================================

## Front player Z position
const FRONT_PLAYER_Z: float = 12.3828

## Back player Z position
const BACK_PLAYER_Z: float = -15.0306

## Player service line position
const SERVICE_LINE_Z: float = 6.302
