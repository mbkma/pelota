class_name PlayStyleProfile
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

## Preference for forehand topspin-heavy patterns.
@export_range(0.0, 1.0, 0.01) var forehand_topspin_preference: float = 0.5
## Preference for using backhand slice under pressure or on lower balls.
@export_range(0.0, 1.0, 0.01) var backhand_slice_preference: float = 0.5
## Frequency of injecting drop shots into neutral rallies.
@export_range(0.0, 1.0, 0.01) var drop_shot_frequency: float = 0.1
## Frequency of driving inside-out forehands when space opens up.
@export_range(0.0, 1.0, 0.01) var inside_out_forehand_frequency: float = 0.2
## Preference for extending rallies instead of finishing quickly.
@export_range(0.0, 1.0, 0.01) var rally_tolerance: float = 0.5
## General willingness to take tactical risk.
@export_range(0.0, 1.0, 0.01) var risk_taking: float = 0.5
## Preferred contact height relative to neutral ball contact.
@export_range(-1.0, 1.0, 0.01) var preferred_contact_height: float = 0.0
## Preferred distance from the baseline, where negative values mean inside the court.
@export_range(-20.0, 20.0, 0.1) var preferred_distance_to_baseline: float = 0.0
## Aggression on serve plus one patterns.
@export_range(0.0, 1.0, 0.01) var serve_plus_one_aggression: float = 0.5
## Preferred return depth from the baseline measured in meters behind the line.
@export_range(-12.0, 0.0, 0.1) var return_position_depth: float = -4.0
## General shot variety preference.
@export_range(0.0, 1.0, 0.01) var variety: float = 0.5
## Preference for flatter contact and lower-margin striking.
@export_range(0.0, 1.0, 0.01) var flat_hitting_preference: float = 0.5
