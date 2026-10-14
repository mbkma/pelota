## Headlines of the tournament, written from the results of the draw: the champion, the player's
## own matches, upsets of seeds, comebacks from two sets down, five-setters, long tiebreaks and
## bagels. The latest round comes first, the bigger story first within a round.
class_name TournamentNews

enum Kind { CHAMPION, OWN, UPSET, COMEBACK, FIVE_SETTER, TIEBREAK, BAGEL }

## Theme type of each kind's round badge
const KIND_BADGES: Dictionary = {
	Kind.CHAMPION: &"BadgeAmber",
	Kind.OWN: &"BadgeTeal",
	Kind.UPSET: &"BadgeRed",
	Kind.COMEBACK: &"BadgeRed",
	Kind.FIVE_SETTER: &"BadgePurple",
	Kind.TIEBREAK: &"BadgePurple",
	Kind.BAGEL: &"BadgePurple",
}
## A seed beaten by a player seeded at least this much lower is an upset
const UPSET_SEED_GAP: int = 8
## Tiebreak points the loser needs for a long tiebreak (e.g. 12-10)
const LONG_TIEBREAK_POINTS: int = 9


## Up to `limit` headlines, each {"match": TournamentMatch, "kind": Kind, "text": String}.
static func headlines(tournament: Tournament, limit: int = 8) -> Array[Dictionary]:
	var news: Array[Dictionary] = []
	for round_index in range(tournament.current_round, -1, -1):
		var round_news: Array[Dictionary] = []
		for m in tournament.round_matches(round_index):
			if m.is_played():
				var story: Dictionary = _story(m, tournament)
				if not story.is_empty():
					round_news.append(story)
		round_news.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool: return a["weight"] > b["weight"]
		)
		news.append_array(round_news)
		if news.size() >= limit:
			break
	return news.slice(0, limit)


## The biggest story of `m`, empty if there is none.
static func _story(m: TournamentMatch, tournament: Tournament) -> Dictionary:
	var winner: PlayerData = m.get_winner()
	var loser: PlayerData = m.get_loser()
	var w: String = winner.full_name()
	var l: String = _seeded(loser, tournament)
	var round_name: String = tournament.round_name(m.round_index)
	if m.round_index == tournament.round_count() - 1:
		return _make(
			m,
			Kind.CHAMPION,
			100,
			"%s wins the %s, beating %s %s" % [w, Tournament.NAME, l, m.score]
		)
	if m.has_player(tournament.player):
		var next: String = tournament.round_name(m.round_index + 1)
		if winner == tournament.player:
			return _make(m, Kind.OWN, 90, "You beat %s %s and reach the %s" % [l, m.score, next])
		return _make(m, Kind.OWN, 90, "%s ends your run in the %s" % [w, round_name])
	var winner_seed: int = tournament.seed_of(winner)
	var loser_seed: int = tournament.seed_of(loser)
	if loser_seed > 0 and (winner_seed == 0 or winner_seed - loser_seed >= UPSET_SEED_GAP):
		return _make(
			m,
			Kind.UPSET,
			60 + Tournament.SEED_COUNT - loser_seed,
			"Upset! %s knocks out %s in the %s" % [_seeded(winner, tournament), l, round_name]
		)
	var games: Array[Vector2i] = m.set_games
	if games.size() == 5:
		var lost_first_two: bool = (
			games[0][m.winner] < games[0][1 - m.winner]
			and games[1][m.winner] < games[1][1 - m.winner]
		)
		if lost_first_two:
			return _make(
				m, Kind.COMEBACK, 55, "%s comes back from two sets down against %s" % [w, l]
			)
		return _make(m, Kind.FIVE_SETTER, 40, "%s outlasts %s in five sets, %s" % [w, l, m.score])
	for set_index in games.size():
		if m.tiebreak_loser_points(set_index) >= LONG_TIEBREAK_POINTS:
			var points: Vector2i = m.set_tiebreaks[set_index]
			return _make(
				m,
				Kind.TIEBREAK,
				30,
				(
					"%s edges %s in a %d-%d tiebreak"
					% [w, l, maxi(points.x, points.y), mini(points.x, points.y)]
				)
			)
	for set_games in games:
		if set_games[m.winner] == Score.GAMES_PER_SET and set_games[1 - m.winner] == 0:
			return _make(m, Kind.BAGEL, 20, "%s serves up a bagel to %s, %s" % [w, l, m.score])
	return {}


static func _make(m: TournamentMatch, kind: Kind, weight: int, text: String) -> Dictionary:
	return {"match": m, "kind": kind, "weight": weight, "text": text}


## "(3) Alexander Zverev", or the name alone for an unseeded player.
static func _seeded(player: PlayerData, tournament: Tournament) -> String:
	var seed_number: int = tournament.seed_of(player)
	return "(%d) %s" % [seed_number, player.full_name()] if seed_number > 0 else player.full_name()
