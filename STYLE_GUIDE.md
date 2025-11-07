# Pelota GDScript Style Guide

This guide ensures consistent, maintainable code across the Pelota project. All new code and refactored code should follow these standards.

---

## 1. Naming Conventions

### Files & Classes
```gdscript
# File: player.gd
class_name Player          # PascalCase for class names
extends CharacterBody3D

# File: match_manager.gd
class_name MatchManager    # PascalCase, no underscores
extends Node
```

### Variables

#### Public Variables
```gdscript
# Exported variables (editor-visible)
@export var move_speed: float = 5.0
@export var health_points: int = 100

# Public member variables (visible to other scripts)
var current_score: int = 0
var is_serving: bool = false
```

#### Private Variables
```gdscript
# Private/internal variables - use underscore prefix
var _internal_timer: float = 0.0
var _cached_trajectory: Array[TrajectoryStep] = []
var _is_moving: bool = false

# Note: Single underscore for private, NOT double underscore
# Double underscore can cause name mangling issues
```

#### Constants
```gdscript
# Global constants - ALL_CAPS
const GRAVITY: float = 9.81
const MAX_PLAYERS: int = 2
const DEFAULT_SPEED: float = 5.0

# Use GameConstants module for centralized values
# See src/globals/game_constants.gd
```

#### Special Variables
```gdscript
# Readonly/onready variables
@onready var animation_tree: AnimationTree = $Model/AnimationTree
@onready var model: Model = $Model

# Signals use snake_case
signal player_moved(position: Vector3)
signal ball_hit(force: float)
```

### Functions

#### Public Functions
```gdscript
# Most functions are public - no prefix needed
func apply_movement(direction: Vector3, delta: float) -> void:
    """Apply player movement in given direction."""
    # implementation

func get_trajectory_prediction() -> Array[TrajectoryStep]:
    """Get predicted ball trajectory."""
    return []

func is_valid() -> bool:
    """Check if player state is valid."""
    return true
```

#### Private Functions
```gdscript
# Internal/private functions - use underscore prefix
func _calculate_stroke_power(pace: float) -> float:
    """Calculate final stroke power."""
    return 0.0

func _get_move_direction() -> Vector3:
    """Get current movement direction from input."""
    return Vector3.ZERO

# Virtual/override functions - standard names
func _ready() -> void:
    """Called when node enters the scene tree."""
    pass

func _physics_process(delta: float) -> void:
    """Called for physics updates."""
    pass
```

---

## 2. Type Hints

All code must have complete type hints. This is non-negotiable.

### Function Parameters & Returns
```gdscript
# CORRECT - Full typing
func calculate_velocity(
    initial_position: Vector3,
    target_position: Vector3,
    spin: float
) -> Vector3:
    var result: Vector3 = Vector3.ZERO
    # ...
    return result

# INCORRECT - No typing
func calculate_velocity(initial_pos, target_pos, spin):
    var result = Vector3.ZERO
    # ...
    return result

# INCORRECT - Partial typing
func calculate_velocity(
    initial_position: Vector3,
    target_position: Vector3,
    spin  # MISSING TYPE!
) -> Vector3:
    # ...
```

### Variable Declarations
```gdscript
# Correct - explicit types
var current_velocity: Vector3 = Vector3.ZERO
var move_speed: float = 5.0
var player_list: Array[Player] = []
var stats_dict: Dictionary = {}

# Acceptable - type inference (simple cases)
var velocity := Vector3.ZERO  # Type inferred from assignment
var speed := 5.0

# WRONG - no type hint
var velocity = Vector3.ZERO  # Should use : or :=
var speed = 5.0              # Should use : or :=
```

### Complex Types
```gdscript
# Arrays with specific types
var trajectories: Array[TrajectoryStep] = []
var players: Array[Player] = []

# Typed Dictionary (Godot 4.0+)
var player_stats: Dictionary[String, float] = {}

# Callable types
var callback: Callable = Callable()

# Optional types (use null safety)
var optional_player: Player = null
if optional_player:  # Always null-check
    optional_player.apply_movement(direction, delta)
```

---

## 3. Documentation Comments

Every public function and class needs documentation comments using Godot's doc format.

### Class Documentation
```gdscript
## Manages ball physics and collision detection
## Handles trajectory prediction and spin-to-gravity conversion
class_name Ball
extends CharacterBody3D
```

### Function Documentation
```gdscript
## Applies a stroke to the ball with given velocity and spin
## This updates the ball's velocity and trajectory for prediction
func apply_stroke(stroke_velocity: Vector3, spin_amount: float) -> void:
    spin = spin_amount
    velocity = stroke_velocity

## Predicts ball trajectory for the next N steps
## Used by AI and aiming systems
## Returns: Array of trajectory points with timestamps
func predict_trajectory(
    steps: int = 200,
    time_step: float = 0.016
) -> Array[TrajectoryStep]:
    # ...
```

### Variable Documentation
```gdscript
## Ball damping factor (0.0-1.0, higher = more bounce)
const BALL_DAMPING: float = 0.7

## Player's current movement speed (units/sec)
var move_speed: float = 5.0

## Cached trajectory for the current ball trajectory
var _cached_trajectory: Array[TrajectoryStep] = []
```

---

## 4. Code Organization

### Class Structure Order
```gdscript
class_name PlayerController
extends Node

# 1. Signals
signal player_moved(position: Vector3)
signal stroke_executed(stroke: Stroke)

# 2. Enums
enum InputMode { KEYBOARD, CONTROLLER, AI }

# 3. Constants
const PLAYER_SPEED: float = 5.0
const MAX_STROKE_POWER: float = 100.0

# 4. Exports (editor variables)
@export var move_speed: float = 5.0
@export var input_mode: InputMode = InputMode.KEYBOARD

# 5. Onready variables
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var model: Model = $Model

# 6. Public member variables
var is_serving: bool = false
var current_stroke: Stroke = null

# 7. Private member variables
var _move_velocity: Vector3 = Vector3.ZERO
var _stroke_cooldown: float = 0.0

# 8. Lifecycle methods (_ready, _process, etc.)
func _ready() -> void:
    pass

func _process(delta: float) -> void:
    pass

# 9. Public methods (in logical groups)
func apply_movement(direction: Vector3, delta: float) -> void:
    pass

func queue_stroke(stroke: Stroke) -> void:
    pass

# 10. Private methods
func _calculate_velocity() -> Vector3:
    return Vector3.ZERO

func _update_animation() -> void:
    pass

# 11. Signal handlers
func _on_ball_hit() -> void:
    pass

func _on_match_state_changed(new_state: int) -> void:
    pass
```

### Method Grouping
```gdscript
## Movement related
#####################

func apply_movement(direction: Vector3, delta: float) -> void:
    pass

func compute_move_dir() -> Vector3:
    return Vector3.ZERO

## Stroke related
###################

func queue_stroke(stroke: Stroke) -> void:
    pass

func apply_stroke(stroke: Stroke) -> void:
    pass

## Private helpers
####################

func _calculate_power() -> float:
    return 0.0
```

---

## 5. Constants & Configuration

### Centralized Constants
```gdscript
# Use GameConstants module for all gameplay values
# File: src/globals/game_constants.gd

# In your code:
var gravity = GameConstants.GRAVITY
var move_speed = GameConstants.PLAYER_MOVE_SPEED

# DO NOT hardcode:
var gravity = 9.81  # WRONG!
```

### Local Constants (when needed)
```gdscript
# For values specific to one file, define at top of class
class_name MyClass
extends Node

const PHYSICS_TIMESTEP: float = 0.016
const ANIMATION_SPEED_FACTOR: float = 1.2

# Then use throughout
var time_step: float = PHYSICS_TIMESTEP
```

---

## 6. Error Handling

Always validate inputs and handle error cases:

```gdscript
## Apply a stroke with validation
func apply_stroke(stroke: Stroke) -> bool:
    # Validate input
    if stroke == null:
        push_error("Cannot apply null stroke")
        return false

    if stroke.stroke_power < 0:
        push_error("Stroke power must be non-negative")
        return false

    # Validate state
    if not player.ball:
        push_error("No ball available for stroke")
        return false

    # Perform action
    player.ball.apply_stroke(stroke.velocity, stroke.spin)
    return true
```

---

## 7. Signal Usage

### Signal Definition
```gdscript
# Include parameter types
signal ball_hit(force: float, position: Vector3)
signal player_moved(old_position: Vector3, new_position: Vector3)

# For simple signals
signal match_started
signal match_ended
```

### Signal Emission
```gdscript
# Always emit with full context
ball_hit.emit(velocity.length(), position)
player_moved.emit(old_pos, new_pos)
match_ended.emit()

# Don't use old emit_signal syntax
# emit_signal("ball_hit", velocity.length(), position)  # WRONG
```

### Signal Connection
```gdscript
# Connect with proper syntax
player.ball_hit.connect(_on_player_ball_hit)
match_manager.state_changed.connect(_on_match_state_changed)

# Use lambdas for simple cases
timer.timeout.connect(func(): queue_redraw())
```

---

## 8. Async/Await Patterns

```gdscript
# Use constants for delays
await get_tree().create_timer(GameConstants.FAULT_DELAY).timeout

# For complex async flows, use helper functions
func _wait_for_player_ready() -> void:
    var timeout: float = GameConstants.PLAYER_READY_TIMEOUT
    var start_time: float = Time.get_ticks_msec()

    while not is_ready:
        if Time.get_ticks_msec() - start_time > timeout:
            push_error("Player ready timeout")
            break
        await get_tree().process_frame

# Document async behavior
## Waits for ball to land before continuing
## Returns: True if landed, False if timeout
func wait_for_ball_land(timeout_sec: float = 5.0) -> bool:
    var start: float = Time.get_ticks_msec()
    while not ball.is_on_ground:
        if Time.get_ticks_msec() - start > timeout_sec * 1000:
            return false
        await get_tree().physics_frame
    return true
```

---

## 9. Common Patterns

### Null Checks
```gdscript
# CORRECT - explicit null check
if player != null:
    player.apply_movement(direction, delta)

# Also correct - implicit truthiness check
if player:
    player.apply_movement(direction, delta)

# WRONG - comparison to null
if player == null:  # Awkward, use "if not player" instead
    return
```

### Type Checking
```gdscript
# Check types when needed
if collision.get_collider() is Net:
    # Handle net collision
    pass
elif collision.get_collider() is Court:
    # Handle court collision
    pass
```

### Dictionary Access with Defaults
```gdscript
# Use get() with default for safe access
var speed: float = stats.get("speed", 100.0)
var pace: float = stats.get("forehand_pace", 25.0)

# WRONG - unsafe direct access
var speed = stats["speed"]  # Crashes if key doesn't exist!
```

---

## 10. Performance Tips

### Avoid Repeated Calculations
```gdscript
# WRONG - recalculates every time
func _process(delta: float) -> void:
    position += get_move_direction() * move_speed * delta

# BETTER - cache if expensive
func _process(delta: float) -> void:
    var direction: Vector3 = _get_move_direction()  # Cache result
    position += direction * move_speed * delta
```

### Use Onready for Scene References
```gdscript
# CORRECT - references cached at startup
@onready var animation_tree: AnimationTree = $AnimationTree

func _process(_delta: float) -> void:
    animation_tree["parameters/move/blend_position"] = blend_pos  # Fast!

# WRONG - lookup every time
func _process(_delta: float) -> void:
    $AnimationTree["parameters/move/blend_position"] = blend_pos  # Slow!
    get_node("AnimationTree")["parameters/move/blend_position"] = blend_pos  # Slower!
```

### Cache Array/Dictionary Lookups
```gdscript
# If accessing same key multiple times
var forehand_pace: float = stats.get("forehand_pace", 25.0)
var forehand_spin: float = stats.get("forehand_spin", 5.0)

# Use in multiple places
stroke.stroke_power = forehand_pace + input_pace
animation_tree["parameters/forehand_spin"] = forehand_spin
```

---

## 11. Checklist for Code Review

Before submitting code for review, ensure:

- [ ] All functions have return type hints
- [ ] All parameters have type hints
- [ ] No magic numbers (use constants)
- [ ] Private members have underscore prefix
- [ ] Public documentation comments on all public functions
- [ ] No dead/commented code
- [ ] No debug print() statements (unless marked as temporary)
- [ ] Proper null checks where needed
- [ ] Consistent naming throughout
- [ ] Signals have parameter types
- [ ] Error cases handled appropriately
- [ ] Code is organized in logical sections

---

## References

- [Godot GDScript Documentation](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/)
- [Godot Style Guide](https://docs.godotengine.org/en/stable/community/contributing/development/code_style_guidelines.html)
- [Godot Best Practices](https://docs.godotengine.org/en/stable/tutorials/3d/using_3d_characters/using_3d_characters.html)

---

*Version: 1.0*
*Last Updated: 2024-11-07*
