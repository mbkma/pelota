class_name AiPlayStyle
extends Resource

## Unique style identifier used by designer presets and debugging output.
@export var style_name: StringName = &"default"

## Higher values make ATTACK intent more likely in qualifying situations.
@export_range(0.0, 1.0, 0.01) var aggression: float = 0.5
## Upper bound for how risky a selected pattern is allowed to be before heavy score penalties apply.
@export_range(0.0, 1.0, 0.01) var risk_tolerance: float = 0.5
## Probability to choose APPROACH_NET when net-approach conditions are met.
@export_range(0.0, 1.0, 0.01) var net_frequency: float = 0.2
## Target outgoing rally pace profile used during pattern scoring (0 prefers lower-power shots, 1 prefers higher-power shots).
## This does not directly change stroke power; it biases dynamic pace synthesis.
@export_range(0.0, 1.0, 0.01) var preferred_rally_pace: float = 0.5
