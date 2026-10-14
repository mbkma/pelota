## Plays a match between two players without showing it, point by point by the rules of Score.
## The server wins a point with the tour's average chance (ATP: ~64% of service points), more
## the better the server's serve is than the returner's return, and the better the server plays
## from the baseline than the returner. Each player has a form of the day, so a match can go
## either way.
class_name MatchSimulator
extends RefCounted

## Share of service points the server wins between two equal players
const SERVE_POINT_CHANCE: float = 0.64
## Change of that share per stat point the serve is better than the return, and per stat point
## the server plays better from the baseline
const SERVE_WEIGHT: float = 0.003
const BASELINE_WEIGHT: float = 0.003
## Lowest and highest share of service points a server wins
const SERVE_POINT_CHANCE_RANGE: Vector2 = Vector2(0.45, 0.85)
## Spread (stat points, standard deviation) of a player's form on the day
const FORM_SPREAD: float = 3.0


## The final score of a match of `best_of_sets` between `players` (index 0 and 1 in the score).
static func play(players: Array[PlayerData], best_of_sets: int) -> Score:
	var score := Score.new()
	score.best_of_sets = best_of_sets
	score.current_server = randi() % 2
	var form: Array[float] = [randfn(0.0, FORM_SPREAD), randfn(0.0, FORM_SPREAD)]
	var serve_chances: Array[float] = [0.0, 0.0]
	for server in 2:
		var returner: int = 1 - server
		var serve_edge: float = (
			serve_rating(players[server].stats) - return_rating(players[returner].stats)
		)
		var baseline_edge: float = (
			baseline_rating(players[server].stats)
			+ form[server]
			- baseline_rating(players[returner].stats)
			- form[returner]
		)
		serve_chances[server] = clampf(
			SERVE_POINT_CHANCE + SERVE_WEIGHT * serve_edge + BASELINE_WEIGHT * baseline_edge,
			SERVE_POINT_CHANCE_RANGE.x,
			SERVE_POINT_CHANCE_RANGE.y
		)
	while not score.is_match_over():
		var server: int = score.current_server
		score.add_point(server if randf() < serve_chances[server] else 1 - server)
	return score


## Share of `runs` simulated matches of `best_of_sets` that `player` wins against `opponent`.
static func win_chance(
	player: PlayerData, opponent: PlayerData, best_of_sets: int, runs: int = 200
) -> float:
	var players: Array[PlayerData] = [player, opponent]
	var wins: int = 0
	for run in runs:
		var score: Score = play(players, best_of_sets)
		if score.sets[0] > score.sets[1]:
			wins += 1
	return float(wins) / runs


static func serve_rating(stats: PlayerStatsProfile) -> float:
	return 0.55 * stats.serve_power + 0.45 * stats.serve_accuracy


static func return_rating(stats: PlayerStatsProfile) -> float:
	return 0.6 * stats.return_skill + 0.2 * stats.top_speed + 0.2 * stats.timing


## How well a player plays the rally: groundstrokes, movement and nerve.
static func baseline_rating(stats: PlayerStatsProfile) -> float:
	return (
		(
			stats.forehand
			+ stats.backhand
			+ stats.consistency
			+ stats.accuracy
			+ stats.top_speed
			+ stats.agility
			+ stats.focus
			+ stats.clutch
		)
		/ 8.0
	)
