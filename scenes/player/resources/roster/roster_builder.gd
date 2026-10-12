## Builds the players from the ATP ranking in RANKING_FILE into PlayerData resources in DATA_DIR.
## Run it after changing the ranking:
##
##     godot --headless --path . -s res://scenes/player/resources/roster/roster_builder.gd
##
## A player with a resource of their own (hand made: stats, play style and look tuned by hand)
## gets the ranking's facts (name, country, age, height, hand, backhand, rank, racket), and their
## stats are shifted to the level of their rank, keeping their strengths and weaknesses. Any other
## player is generated: the stats from the rank (a better ranked player is better all round)
## and the playing style the ranking file gives, with a little variation per player; the play
## style from the playing style; the look from a few shirt and shorts colors. A hand made player
## missing from the ranking keeps playable but unranked (rank 0).
class_name RosterBuilder
extends SceneTree

const RANKING_FILE: String = "res://scenes/player/resources/roster/atp_top_128.csv"
const DATA_DIR: String = "res://scenes/player/resources/data/"
## The racket designs; the ranking names each player's (its "racket" column, a design's file
## name; "racket_source" tells where it is known from, or that it is estimated)
const RACKET_DIR: String = "res://scenes/player/racket/designs/"
## The umpire calling each player's name, one clip per player resource, named like it (see
## pelota-files/sounds/umpire/make_umpire_calls.py)
const NAME_CALL_DIR: String = "res://assets/sounds/effects/umpire/names/"
## Overall level (stat points) of the best and of the 128th ranked player; the level falls off
## with the logarithm of the rank (shifted by RANK_OFFSET, so the very best are close together).
const LEVEL_TOP: float = 88.0
const LEVEL_128: float = 72.0
const RANK_OFFSET: float = 3.0
## Random variation (stat points, both ways) of each generated stat
const STAT_VARIATION: float = 2.5
## Stat changes by playing style
const STYLE_STATS: Dictionary[String, Dictionary] = {
	"big_server":
	{
		"serve_power": 8.0,
		"serve_accuracy": 4.0,
		"return_skill": -5.0,
		"agility": -4.0,
		"top_speed": -3.0,
		"volley_skill": 3.0,
		"net_play": 3.0,
		"consistency": -2.0,
	},
	"aggressive":
	{
		"forehand": 4.0,
		"backhand": 2.0,
		"accuracy": 1.0,
		"consistency": -3.0,
		"topspin_skill": 2.0,
	},
	"baseliner":
	{
		"consistency": 4.0,
		"backhand": 2.0,
		"stamina": 3.0,
		"serve_power": -2.0,
		"net_play": -4.0,
		"volley_skill": -3.0,
	},
	"counterpuncher":
	{
		"top_speed": 6.0,
		"agility": 5.0,
		"return_skill": 6.0,
		"consistency": 5.0,
		"stamina": 4.0,
		"serve_power": -7.0,
		"forehand": -1.0,
	},
	"all_court":
	{
		"volley_skill": 7.0,
		"net_play": 8.0,
		"slice_skill": 6.0,
		"timing": 2.0,
		"consistency": -1.0,
	},
}
## Play style by playing style: aggression, shot power, topspin, court position, consistency
const STYLE_PLAY: Dictionary[String, Array] = {
	"big_server": [0.75, 0.85, 0.45, -0.1, 0.55],
	"aggressive": [0.8, 0.85, 0.65, -0.2, 0.6],
	"baseliner": [0.5, 0.65, 0.75, 0.4, 0.82],
	"counterpuncher": [0.35, 0.55, 0.6, 0.85, 0.9],
	"all_court": [0.65, 0.7, 0.55, -0.3, 0.65],
}
const STYLE_PATTERN: Dictionary[String, AiPlayStyle.PreferredPattern] = {
	"big_server": AiPlayStyle.PreferredPattern.FOREHAND_INSIDE_OUT,
	"aggressive": AiPlayStyle.PreferredPattern.FOREHAND_INSIDE_OUT,
	"baseliner": AiPlayStyle.PreferredPattern.CROSS_CROSS,
	"counterpuncher": AiPlayStyle.PreferredPattern.CROSS_CROSS,
	"all_court": AiPlayStyle.PreferredPattern.RANDOM,
}
## Serve power (stat points) per cm of height above or below AVERAGE_HEIGHT, and the speed lost
## per cm above it
const AVERAGE_HEIGHT: float = 186.0
const SERVE_PER_CM: float = 0.35
const SPEED_PER_CM: float = 0.15
## A one-handed backhand: better slice, a little weaker backhand
const ONE_HANDED_SLICE: float = 5.0
const ONE_HANDED_BACKHAND: float = -1.5
## Clothes colors of generated players
const SHIRT_COLORS: Array[Color] = [
	Color(0.95, 0.95, 0.95),
	Color(0.12, 0.12, 0.14),
	Color(0.1, 0.25, 0.55),
	Color(0.2, 0.55, 0.85),
	Color(0.75, 0.15, 0.15),
	Color(0.95, 0.5, 0.15),
	Color(0.15, 0.55, 0.3),
	Color(0.95, 0.85, 0.3),
	Color(0.5, 0.25, 0.6),
	Color(0.9, 0.45, 0.6),
	Color(0.4, 0.75, 0.75),
]
const SHORTS_COLORS: Array[Color] = [
	Color(0.08, 0.08, 0.1),
	Color(0.95, 0.95, 0.95),
	Color(0.1, 0.12, 0.3),
	Color(0.35, 0.35, 0.38),
]


func _initialize() -> void:
	var rows: Array[Dictionary] = _read_ranking()
	var last_name_counts: Dictionary[String, int] = {}
	for row in rows:
		last_name_counts[row.last_name] = last_name_counts.get(row.last_name, 0) + 1
	var ranked_files: PackedStringArray = []
	for row in rows:
		var file_name: String = _file_name(row, last_name_counts[row.last_name] > 1)
		ranked_files.append(file_name)
		var path: String = DATA_DIR + file_name
		var player: PlayerData
		if ResourceLoader.exists(path):
			player = load(path)
			_shift_to_level(player.stats, _level(int(row.rank)))
		else:
			player = _generated(row)
		_apply_facts(player, row)
		player.name_call = load(NAME_CALL_DIR + file_name.get_basename() + ".ogg")
		_save(player, path)
	for file_name in ResourceLoader.list_directory(DATA_DIR):
		if file_name.get_extension() == "tres" and not ranked_files.has(file_name):
			var unranked: PlayerData = load(DATA_DIR + file_name)
			unranked.rank = 0
			unranked.name_call = load(NAME_CALL_DIR + file_name.get_basename() + ".ogg")
			_save(unranked, DATA_DIR + file_name)
	quit()


func _read_ranking() -> Array[Dictionary]:
	var file := FileAccess.open(RANKING_FILE, FileAccess.READ)
	var header: PackedStringArray = file.get_csv_line()
	var rows: Array[Dictionary] = []
	while not file.eof_reached():
		var values: PackedStringArray = file.get_csv_line()
		if values.size() != header.size():
			continue
		var row: Dictionary = {}
		for i in header.size():
			row[header[i]] = values[i]
		rows.append(row)
	return rows


## Resource file of a player: the last name, with the first name when two players share it.
static func _file_name(row: Dictionary, shared_last_name: bool) -> String:
	var name: String = row.last_name
	if shared_last_name:
		name = "%s %s" % [row.first_name, row.last_name]
	return name.to_lower().replace("'", "").replace(" ", "-") + ".tres"


static func _apply_facts(player: PlayerData, row: Dictionary) -> void:
	player.first_name = row.first_name
	player.last_name = row.last_name
	player.country = row.country
	player.country_code = row.country_code
	player.age = int(row.age)
	player.height = int(row.height)
	player.hand = row.hand
	player.backhand = int(row.backhand)
	player.rank = int(row.rank)
	player.racket = load(RACKET_DIR + row.racket + ".tres")


## Saves `player` to `path`, keeping the UID of the file there (scenes refer to players by it).
static func _save(player: PlayerData, path: String) -> void:
	var uid: int = ResourceLoader.get_resource_uid(path)
	if uid == ResourceUID.INVALID_ID:
		uid = ResourceUID.create_id()
	var error: Error = ResourceSaver.save(player, path)
	assert(error == OK, "Could not save %s: %s" % [path, error_string(error)])
	ResourceSaver.set_uid(path, uid)
	print("saved ", path)


## A player generated from the ranking (see the top of the file).
static func _generated(row: Dictionary) -> PlayerData:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(row.first_name + row.last_name)
	var player := PlayerData.new()
	player.stats = _stats(row, rng)
	player.play_style = _play_style(row.style)
	player.appearance = _appearance(rng)
	return player


## Overall level (mean stat) of the player ranked `rank`.
static func _level(rank: int) -> float:
	var spread: float = log(128.0 + RANK_OFFSET) - log(1.0 + RANK_OFFSET)
	return lerpf(LEVEL_TOP, LEVEL_128, (log(rank + RANK_OFFSET) - log(1.0 + RANK_OFFSET)) / spread)


## The stats of `stats`, which are stored as floats.
static func _stat_names(stats: PlayerStatsProfile) -> PackedStringArray:
	var names: PackedStringArray = []
	for property in stats.get_property_list():
		if property.type == TYPE_FLOAT and property.usage & PROPERTY_USAGE_STORAGE:
			names.append(property.name)
	return names


## Shifts all `stats` by the same amount so their mean is `level`.
static func _shift_to_level(stats: PlayerStatsProfile, level: float) -> void:
	var names: PackedStringArray = _stat_names(stats)
	var total: float = 0.0
	for stat in names:
		total += stats.get(stat)
	var shift: float = level - total / names.size()
	for stat in names:
		stats.set(stat, clampf(roundf(stats.get(stat) + shift), 1.0, 100.0))


static func _stats(row: Dictionary, rng: RandomNumberGenerator) -> PlayerStatsProfile:
	var stats := PlayerStatsProfile.new()
	var level: float = _level(int(row.rank))
	var style: Dictionary = STYLE_STATS[row.style]
	var height_offset: float = float(row.height) - AVERAGE_HEIGHT
	for stat in _stat_names(stats):
		var value: float = level + style.get(stat, 0.0)
		value += rng.randf_range(-STAT_VARIATION, STAT_VARIATION)
		match stat:
			"serve_power":
				value += height_offset * SERVE_PER_CM
			"top_speed", "agility":
				value -= height_offset * SPEED_PER_CM
			"slice_skill":
				value += ONE_HANDED_SLICE if int(row.backhand) == 1 else 0.0
			"backhand":
				value += ONE_HANDED_BACKHAND if int(row.backhand) == 1 else 0.0
		stats.set(stat, clampf(roundf(value), 1.0, 100.0))
	return stats


static func _play_style(style: String) -> AiPlayStyle:
	var values: Array = STYLE_PLAY[style]
	var play_style := AiPlayStyle.new()
	play_style.aggression = values[0]
	play_style.shot_power = values[1]
	play_style.topspin = values[2]
	play_style.court_position = values[3]
	play_style.consistency = values[4]
	play_style.preferred_pattern = STYLE_PATTERN[style]
	return play_style


static func _appearance(rng: RandomNumberGenerator) -> PlayerAppearance:
	var appearance := PlayerAppearance.new()
	appearance.shirt_color = SHIRT_COLORS[rng.randi() % SHIRT_COLORS.size()]
	appearance.shorts_color = SHORTS_COLORS[rng.randi() % SHORTS_COLORS.size()]
	return appearance
