## The men's singles of the US Open: a draw of the 128 best ranked players, seven rounds to the
## title. The player plays their own matches; every other match is simulated (see
## MatchSimulator). A round is finished once the player's match is played: then the other matches
## of the round are simulated and the winners drawn into the next round. Once the player is out,
## the rest of the tournament can be simulated to the end.
##
## The draw is made like a Grand Slam's: the 32 best ranked players are seeded and kept apart
## (seeds 1 and 2 can only meet in the final, 1 to 4 in the semifinals, 1 to 8 in the
## quarterfinals, and so on), the others are drawn at random into the remaining places.
class_name Tournament
extends Resource

const NAME: String = "US Open"
const DRAW_SIZE: int = 128
const SEED_COUNT: int = 32
const ROUND_NAMES: PackedStringArray = [
	"1st Round", "2nd Round", "3rd Round", "4th Round", "Quarterfinals", "Semifinals", "Final"
]
## Sets of the simulated matches (men's singles at a Grand Slam: best of five)
const SIMULATED_BEST_OF_SETS: int = 5
## Where the running tournament is saved
const SAVE_PATH: String = "user://us_open.tres"

## The player's own player
@export var player: PlayerData
## Sets of the player's own matches
@export var best_of_sets: int = 3
## Seeded players, the first seed first
@export var seeds: Array[PlayerData] = []
## All matches played or drawn so far, round by round, each round in draw order
@export var matches: Array[TournamentMatch] = []
## Round being played
@export var current_round: int = 0


## A new tournament of the best ranked `entrants` (at least DRAW_SIZE, best ranked first), in
## which the player plays `own_player`.
static func create(
	entrants: Array[PlayerData], own_player: PlayerData, own_best_of_sets: int
) -> Tournament:
	var tournament := Tournament.new()
	tournament.player = own_player
	tournament.best_of_sets = own_best_of_sets
	var field: Array[PlayerData] = entrants.slice(0, DRAW_SIZE)
	if not field.has(own_player):
		# A player outside the field takes the place of the lowest ranked one.
		field[DRAW_SIZE - 1] = own_player
	tournament.seeds = field.slice(0, SEED_COUNT)
	var lines: Array[PlayerData] = _draw(field)
	for i in range(0, DRAW_SIZE, 2):
		var first_round := TournamentMatch.new()
		first_round.players = [lines[i], lines[i + 1]]
		tournament.matches.append(first_round)
	return tournament


## The saved tournament, or null if there is none.
static func load_saved() -> Tournament:
	if not ResourceLoader.exists(SAVE_PATH):
		return null
	return ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)


func save() -> void:
	var error: Error = ResourceSaver.save(self, SAVE_PATH)
	assert(error == OK, "Could not save the tournament: %s" % error_string(error))


func round_count() -> int:
	return ROUND_NAMES.size()


func round_name(round_index: int) -> String:
	return ROUND_NAMES[round_index]


func round_matches(round_index: int) -> Array[TournamentMatch]:
	return matches.filter(func(m: TournamentMatch) -> bool: return m.round_index == round_index)


## Seed (1 to SEED_COUNT) of `entrant`, 0 if not seeded.
func seed_of(entrant: PlayerData) -> int:
	return seeds.find(entrant) + 1


func is_over() -> bool:
	var final: Array[TournamentMatch] = round_matches(round_count() - 1)
	return not final.is_empty() and final[0].is_played()


func champion() -> PlayerData:
	return round_matches(round_count() - 1)[0].get_winner()


## The player's match of the current round, null once the player is out or the tournament over.
func player_match() -> TournamentMatch:
	for m in round_matches(current_round):
		if m.has_player(player) and not m.is_played():
			return m
	return null


## The match the player lost, null while the player is still in.
func player_lost_match() -> TournamentMatch:
	for m in matches:
		if m.is_played() and m.has_player(player) and m.get_winner() != player:
			return m
	return null


## Records the player's match of the current round, played to `final_score` (in which the
## player was index 0), simulates the other matches of the round and draws the next round.
func record_player_match(final_score: Score) -> void:
	var own: TournamentMatch = player_match()
	var player_index: int = own.players.find(player)
	var winner_in_score: int = 0 if final_score.sets[0] > final_score.sets[1] else 1
	var winner: int = player_index if winner_in_score == 0 else 1 - player_index
	own.record(winner, _seen_from(final_score, player_index))
	finish_round()


## Simulates the player's match of the current round over the player's sets (instead of playing
## it), then the other matches of the round, and draws the next round.
func simulate_player_match() -> void:
	var own: TournamentMatch = player_match()
	var final_score: Score = MatchSimulator.play(own.players, best_of_sets)
	own.record(0 if final_score.sets[0] > final_score.sets[1] else 1, final_score)
	finish_round()


## Simulates the unplayed matches of the current round and draws the next one.
func finish_round() -> void:
	for m in round_matches(current_round):
		if not m.is_played():
			var final_score: Score = MatchSimulator.play(m.players, SIMULATED_BEST_OF_SETS)
			m.record(0 if final_score.sets[0] > final_score.sets[1] else 1, final_score)
	if current_round == round_count() - 1:
		return
	var winners: Array[PlayerData] = []
	for m in round_matches(current_round):
		winners.append(m.get_winner())
	current_round += 1
	for i in range(0, winners.size(), 2):
		var next := TournamentMatch.new()
		next.round_index = current_round
		next.players = [winners[i], winners[i + 1]]
		matches.append(next)


## Simulates the tournament to the end (once the player is out).
func finish() -> void:
	while not is_over():
		finish_round()


## `final_score` of a match where the players' indices in the draw were the other way around:
## the player was index 0 in the match played, but `player_index` in the draw.
static func _seen_from(final_score: Score, player_index: int) -> Score:
	if player_index == 0:
		return final_score
	var swapped := Score.new()
	for games in final_score.completed_sets:
		swapped.completed_sets.append(Vector2i(games.y, games.x))
	swapped.sets = [final_score.sets[1], final_score.sets[0]]
	return swapped


## The players in draw order: the seeds in their places (see the top of the file), the others at
## random in between.
static func _draw(field: Array[PlayerData]) -> Array[PlayerData]:
	var lines: Array[PlayerData] = []
	lines.resize(DRAW_SIZE)
	# The draw is 32 sections of four lines, one seed per section: the seed at the top of its
	# section in the upper half, at the bottom in the lower half.
	var section_seeds: Array[int] = _bracket_order(SEED_COUNT)
	_shuffle_seed_groups(section_seeds)
	var section_size: int = DRAW_SIZE / SEED_COUNT
	for section in SEED_COUNT:
		var line: int = section * section_size
		if section >= SEED_COUNT / 2:
			line += section_size - 1
		lines[line] = field[section_seeds[section] - 1]
	var unseeded: Array[PlayerData] = field.slice(SEED_COUNT)
	unseeded.shuffle()
	for line in DRAW_SIZE:
		if lines[line] == null:
			lines[line] = unseeded.pop_back()
	return lines


## Seed number per place of a bracket of `count` seeds, such that the better seeds meet as late
## as possible: [1, 2] for 2, [1, 4, 2, 3] for 4 (1 meets 4 and 2 meets 3 first), and so on.
static func _bracket_order(count: int) -> Array[int]:
	var order: Array[int] = [1]
	while order.size() < count:
		var size: int = order.size() * 2
		var next: Array[int] = []
		for s in order:
			next.append(s)
			next.append(size + 1 - s)
		order = next
	return order


## Draws seeds 3 and 4, 5 to 8, 9 to 16 and 17 to 32 at random into their groups' places.
static func _shuffle_seed_groups(section_seeds: Array[int]) -> void:
	for group: Vector2i in [Vector2i(3, 4), Vector2i(5, 8), Vector2i(9, 16), Vector2i(17, 32)]:
		var places: Array[int] = []
		var group_seeds: Array[int] = []
		for section in section_seeds.size():
			var s: int = section_seeds[section]
			if s >= group.x and s <= group.y:
				places.append(section)
				group_seeds.append(s)
		group_seeds.shuffle()
		for i in places.size():
			section_seeds[places[i]] = group_seeds[i]
