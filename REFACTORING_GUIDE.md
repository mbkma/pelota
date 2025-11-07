# Pelota Project Refactoring Guide

## Overview

This document tracks the modernization and refactoring of the Pelota tennis simulation game for Godot 4.5, focusing on code quality, maintainability, and adherence to Godot best practices.

---

## Phase 1: Code Quality & Type Safety ✅ IN PROGRESS

### 1.1 Type Hints Addition
- **Status:** In Progress (20% Complete)
- **Files Completed:**
  - ✅ `src/globals/global_physics.gd` - Added all type hints
  - ✅ `src/players/inputs/keyboard_input.gd` - Complete refactor with full typing
  - ✅ `src/ball.gd` - Added comprehensive type hints

- **Files Pending:**
  - `src/players/player.gd` - Add parameter types to all functions
  - `src/players/model.gd` - Add type hints to animation functions
  - `src/players/inputs/ai/ai_input.gd` - Complete AI input typing
  - `src/players/inputs/ai/tactics/default.gd` - Add AI tactic types
  - `src/tennis_session/match_manager.gd` - Add state machine typing
  - `src/match_score.gd` - Add scoring system types
  - `src/globals/global_utils.gd` - Type all utility functions
  - `src/television/television.gd` - Camera system types
  - `src/umpire/umpire.gd` - Umpire system types
  - `src/crowd/crowd.gd` - Crowd system types

**Guidelines:**
```gdscript
# CORRECT - Full typing
func calculate_trajectory(
    initial_position: Vector3,
    velocity: Vector3,
    spin: float
) -> Array[TrajectoryStep]:
    ...

# INCORRECT - No typing
func calculate_trajectory(initial_pos, velocity, spin):
    ...
```

### 1.2 Debug Print Statement Removal
- **Status:** Pending
- **Impact:** 33+ print statements found
- **Strategy:** Remove or replace with proper logging framework

```gdscript
# REMOVE THESE:
print("Ball position:", position)
print("Match over")

# OR REPLACE WITH LOGGING:
if DEBUG_MODE:
    logger.debug("Ball at position: %s" % str(position))
```

### 1.3 Commented Code Cleanup
- **Status:** Partially Complete (Keyboard Input cleaned)
- **Approach:**
  - Remove dead code blocks > 3 lines
  - Preserve in git history via commits
  - Document reasoning in commit messages

---

## Phase 2: Code Organization & Constants

### 2.1 Constants Module ✅ COMPLETED
- **File:** `src/globals/game_constants.gd`
- **Created as:** class_name GameConstants
- **Sections:**
  - Physics Constants (GRAVITY, BALL_DAMP)
  - Player Constants (speeds, thresholds)
  - Input Constants (mouse sensitivity, delays)
  - AI Constants (stroke targeting, distances)
  - Timing Constants (delays, timeouts)
  - Court Constants
  - Match States Enum

**Usage:**
```gdscript
# Before: Magic numbers everywhere
var gravity = 9.81 + spin * 0.5

# After: Named constants
var gravity = GameConstants.GRAVITY + (spin * 0.5)
```

### 2.2 Variable Naming Convention Standardization
- **Status:** In Progress

**Rules:**
```gdscript
# Private/Internal variables - use underscore prefix
var _internal_state: int = 0
var _cached_value: float = 0.0

# Public/Exported variables - no underscore
@export var move_speed: float = 5.0
var public_data: String = ""

# Constants - ALL_CAPS
const MAX_HEALTH: int = 100
const PLAYER_COUNT: int = 2

# Private constants - same as normal constants
const _INTERNAL_BUFFER_SIZE: int = 256

# Private functions - underscore prefix
func _internal_calculation() -> float:
    ...

# Public functions - no underscore (most functions are public in Godot)
func apply_movement(direction: Vector3, delta: float) -> void:
    ...
```

**Priority Files for Naming:**
1. `ball.gd` - Already mostly correct
2. `player.gd` - Many public vars should be private
3. `model.gd` - Animation state needs proper naming
4. `keyboard_input.gd` - ✅ COMPLETED
5. `ai_input.gd` - Needs standardization
6. `match_manager.gd` - Many members need underscore prefix

### 2.3 AI Tactics Data-Driven System
- **Status:** Pending
- **Goal:** Move hardcoded stroke values to configuration

**Before:**
```gdscript
# In default.gd - duplicated across match scenarios
stroke.stroke_target = Vector3(-sign(player.position.x) * 3, 0, -sign(player.position.z) * 10)
```

**After (Planned):**
```gdscript
# Configuration-based
var tactics_config = {
    "serve_wide": {"x_offset": 3, "z_distance": 5},
    "forehand_cross": {"x_offset": -3, "z_distance": 10},
}

stroke.stroke_target = _get_target_from_config(tactic_name)
```

---

## Phase 3: Architecture Improvements

### 3.1 InputMethod Base Class Enhancement
- **Status:** Pending
- **Current:** Only has `request_serve()` stub
- **Goal:** Full abstraction for input systems

**Planned Interface:**
```gdscript
class_name InputMethod
extends Node

var player: Player

# Core interface
func request_serve() -> void:
    push_error("Implement in subclass")

func get_move_direction() -> Vector3:
    return Vector3.ZERO

func execute_stroke() -> Stroke:
    return null

func clear_input_state() -> void:
    pass
```

### 3.2 Folder Structure Reorganization
- **Status:** Pending
- **Current Structure Issues:**
  - Some related scripts scattered
  - No clear separation of concerns

**Proposed Structure:**
```
/src/
├── core/
│   ├── game_constants.gd
│   ├── global_physics.gd
│   └── global_utils.gd
├── players/
│   ├── player.gd (main player class)
│   ├── model.gd (animation & visuals)
│   ├── inputs/
│   │   ├── input_method.gd (base class)
│   │   ├── human_input.gd (keyboard/mouse)
│   │   └── ai_input.gd (with subdir tactics/)
│   └── resources/
│       └── player_data.gd
├── match/
│   ├── match_manager.gd
│   ├── match_score.gd
│   ├── match_data.gd
│   └── court.gd
├── ball/
│   ├── ball.gd
│   └── trajectory_step.gd
├── physics/
│   ├── global_physics.gd (moved from globals)
│   └── physics_utils.gd
├── ui/
│   ├── hud/
│   ├── menus/
│   └── television/
├── gameplay/
│   ├── crowd/
│   ├── umpire/
│   └── stadium.gd
└── scenes/
    ├── tennis_match.tscn
    └── main_menu.tscn
```

### 3.3 Error Handling & Validation
- **Status:** Pending
- **Goal:** Add null checks, validate inputs

```gdscript
# Example pattern
func apply_stroke(stroke: Stroke) -> bool:
    if not stroke:
        push_error("Cannot apply null stroke")
        return false

    if stroke.stroke_power < 0:
        push_error("Stroke power must be positive")
        return false

    # Perform action
    return true
```

---

## Phase 4: Performance & Optimization

### 4.1 Ball Trajectory Optimization
- **Status:** Pending (marked as FIXME)
- **Current:** Full re-prediction every frame
- **Proposal:** Cache trajectory, only update when ball velocity changes

### 4.2 Property Optimization
- **Status:** Pending
- **Goal:** Use `@onready` instead of `get_parent()` where safe

---

## Implementation Checklist

### Phase 1 Tasks
- [ ] Complete type hints on all functions
- [ ] Remove all debug print() statements
- [ ] Clean commented code blocks
- [ ] Test all existing functionality (regression testing)

### Phase 2 Tasks
- [ ] Update all files to use GameConstants
- [ ] Standardize variable naming (underscore prefix for private)
- [ ] Create AI tactics configuration system
- [ ] Document all public APIs

### Phase 3 Tasks
- [ ] Enhance InputMethod base class
- [ ] Reorganize folder structure
- [ ] Add error handling & validation throughout
- [ ] Create architecture documentation

### Phase 4 Tasks
- [ ] Optimize ball trajectory prediction
- [ ] Profile and optimize hot paths
- [ ] Add unit tests
- [ ] Performance benchmarking

---

## Code Review Checklist

Use this when reviewing refactored code:

- [ ] All functions have return type hints
- [ ] All function parameters have type hints
- [ ] No magic numbers (use constants)
- [ ] Private variables start with underscore
- [ ] No dead/commented code
- [ ] No print() statements (unless development debug)
- [ ] Proper documentation comments (##)
- [ ] Follows Godot naming conventions
- [ ] No duplicate functions
- [ ] Error cases handled gracefully

---

## Resource Files (for reference)

### Key Godot 4.5 Best Practices Used:
1. **Documentation Comments:** `## Comment style` for doc generation
2. **Type Hints:** Full typing for IDE support and runtime safety
3. **Signal Definitions:** `signal name(param_type: Type)`
4. **Export Variables:** `@export var name: Type`
5. **Readonly Variables:** `@onready var name: Type`
6. **Private Naming:** Leading underscore for internal members
7. **Constants:** `const NAME: Type = value`

### References:
- [Godot GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html)
- [Godot Best Practices](https://docs.godotengine.org/en/stable/community/contributing/development/code_style_guidelines.html)

---

## Timeline & Effort Estimate

| Phase | Tasks | Effort | Priority |
|-------|-------|--------|----------|
| 1 | Type hints, cleanup | 8-10 hrs | HIGH |
| 2 | Constants, naming | 6-8 hrs | HIGH |
| 3 | Architecture | 10-12 hrs | MEDIUM |
| 4 | Performance | 6-8 hrs | MEDIUM |

**Total Estimated Effort:** 30-38 hours

---

## Notes

- All refactoring maintains 100% functional compatibility
- Changes are backward compatible with existing scenes
- Git commits at logical points for easy rollback if needed
- Test after each phase to ensure no regressions

---

*Last Updated: 2024-11-07*
*Refactoring Lead: Claude Code AI*
