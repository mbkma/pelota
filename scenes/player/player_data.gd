class_name PlayerData
extends Resource

@export var first_name := ""
@export var last_name := ""
@export var age := 20
@export var country := ""
@export var height := 180
@export var hand := "R"
@export var backhand := 2
@export var rank := 1
## Identity-layer play style profile used by tactical systems.
@export var play_style: PlayStyleProfile
## Full gameplay stat profile used by movement, stamina, shot synthesis, and AI behavior.
@export var stats: PlayerStatsProfile
## Visual profile that defines body, clothing, and hair mesh variants.
@export var appearance: PlayerAppearance
@export var sounds := {
	"grunt_flat": [],
	"grunt_frequency": 0.0,
	"victory": [],
}
