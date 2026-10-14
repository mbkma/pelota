class_name PlayerData
extends Resource

@export var first_name := ""
@export var last_name := ""
@export var age := 20
@export var country := ""
## Three-letter country code, as TV graphics show it (e.g. "ITA")
@export var country_code := ""
@export var height := 180
@export var hand := "R"
@export var backhand := 2
## ATP singles ranking; 0 for a player without one (e.g. retired)
@export var rank := 1
## Identity-layer play style profile used by tactical systems.
@export var play_style: AiPlayStyle
## Full gameplay stat profile used by movement, stamina, shot synthesis, and AI behavior.
@export var stats: PlayerStatsProfile
## Body of the player: an imported player body (see scenes/player/rig/player_body_import.gd);
## none for the model's default body.
@export var body: PackedScene
## Textures and colors of the body
@export var appearance: PlayerAppearance
## The racket the player plays with: its brand and look
@export var racket: RacketDesign
## The umpire saying the player's name (see UmpireCalls)
@export var name_call: AudioStream
@export var sounds := {
	"grunt_flat": [],
	"grunt_frequency": 0.0,
	"victory": [],
}


## "Carlos Alcaraz"
func full_name() -> String:
	return "%s %s" % [first_name, last_name]


## Name as on a draw: "C. Alcaraz"
func short_name() -> String:
	return "%s. %s" % [first_name.left(1), last_name]
