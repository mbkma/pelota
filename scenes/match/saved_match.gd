## A match saved between points, to be continued later from the start of the next point: its
## players, the devices playing them and the match so far (score, statistics and match time). The
## match manager saves it after every point and deletes it when the match is over or a new one
## starts. One match outside a tournament and the player's match of the saved tournament are saved
## at a time; a match of the tournament is continued from the tournament.
class_name SavedMatch
extends Resource

## Where a match outside a tournament is saved, and where the player's match of the tournament
const SAVE_PATH: String = "user://match.tres"
const TOURNAMENT_SAVE_PATH: String = "user://us_open_match.tres"

## Player 1 and player 2 of the match (in a tournament: the player and the opponent)
@export var players: Array[PlayerData] = []
## Device id per team (see GlobalGameData.set_match_input_devices)
@export var input_devices: Array[int] = []
## Whether the match is the player's match of the saved tournament
@export var in_tournament: bool = false
@export var match_data: MatchData


static func create(
	match_players: Array[PlayerData], devices: Array[int], tournament_match: bool, data: MatchData
) -> SavedMatch:
	var saved := SavedMatch.new()
	saved.players = match_players
	saved.input_devices = devices
	saved.in_tournament = tournament_match
	saved.match_data = data
	return saved


## The saved match outside a tournament (or of the tournament), or null if there is none.
static func load_saved(tournament_match: bool) -> SavedMatch:
	var path: String = _save_path(tournament_match)
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)


static func delete_saved(tournament_match: bool) -> void:
	var path: String = _save_path(tournament_match)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func save() -> void:
	var error: Error = ResourceSaver.save(self, _save_path(in_tournament))
	assert(error == OK, "Could not save the match: %s" % error_string(error))


static func _save_path(tournament_match: bool) -> String:
	return TOURNAMENT_SAVE_PATH if tournament_match else SAVE_PATH


## Whether this is the match of `player` against `opponent`.
func is_between(player: PlayerData, opponent: PlayerData) -> bool:
	return players.size() == 2 and players[0] == player and players[1] == opponent


## The score as on a scoreboard, from player 1's side (e.g. "6-4 2-3").
func score_text() -> String:
	var score: Score = match_data.score
	var sets: PackedStringArray = []
	for games in score.completed_sets:
		sets.append("%d-%d" % [games.x, games.y])
	sets.append("%d-%d" % [score.games[0], score.games[1]])
	return " ".join(sets)
