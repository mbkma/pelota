class_name AiPlayStyle
extends Resource

enum PreferredPattern {
	RANDOM,
	CROSS_CROSS,
	FOREHAND_INSIDE_OUT,
}

## Higher values make ATTACK intent more likely in qualifying situations.
@export_range(0.0, 1.0, 0.01) var aggression: float = 0.5
## Preferred rally pace and finishing pace tendency.
@export_range(0.0, 1.0, 0.01) var shot_power: float = 0.5
## Preference for high-margin topspin trajectories.
@export_range(0.0, 1.0, 0.01) var topspin: float = 0.5
## Preferred baseline depth: -1.0 inside baseline, 0.0 on baseline, 1.0 deep behind baseline.
@export_range(-1.0, 1.0, 0.01) var court_position: float = 0.0
## Tendency to repeat high-percentage patterns and avoid volatility.
@export_range(0.0, 1.0, 0.01) var consistency: float = 0.5
## Hidden tactical pattern preference to make players recognizable.
@export_storage var preferred_pattern: PreferredPattern = PreferredPattern.RANDOM
