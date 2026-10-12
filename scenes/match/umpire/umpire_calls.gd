## The umpire's calls, spoken by text to speech (see pelota-files/sounds/umpire/
## make_umpire_calls.py). The players' names are separate clips (PlayerData.name_call) played
## after a call that names a player ("Advantage," and then "Sinner").
class_name UmpireCalls
extends Resource

## Point scores by "<server's points>-<receiver's points>" (Score.TennisPoint values, e.g. "1-2"
## for "Fifteen, thirty"), without 0-0 and 3-3 (deuce)
@export var scores: Dictionary[String, AudioStream] = {}
@export var deuce: AudioStream
@export var advantage: AudioStream
@export var game: AudioStream
## "Game and first set," to "Game and fifth set,"
@export var game_and_set: Array[AudioStream] = []
@export var game_set_and_match: AudioStream
@export var tiebreak: AudioStream
## Tiebreak scores by "<leader's points>-<trailer's points>" up to twenty ("3-1" is
## "Three, one", the leader's name follows), and the ties ("2-2" is "Two all")
@export var tiebreak_scores: Dictionary[String, AudioStream] = {}
@export var let: AudioStream
## Electronic line calls: a serve out, and a rally ball out
@export var fault: AudioStream
@export var out: AudioStream
