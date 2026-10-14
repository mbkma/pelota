## One match of a player's way through the draw on their profile: the round, W or L, the
## opponent and the score from the player's side.
class_name PathRow
extends HBoxContainer


func show_match(player: PlayerData, player_match: TournamentMatch, tournament: Tournament) -> void:
	%RoundLabel.text = tournament.round_short_name(player_match.round_index)
	var result_badge: PanelContainer = %ResultBadge
	var result_label: Label = %ResultLabel
	result_label.text = "-"
	result_badge.theme_type_variation = &"BadgePurple"
	if player_match.is_played():
		var won: bool = player_match.get_winner() == player
		result_label.text = "W" if won else "L"
		result_badge.theme_type_variation = &"BadgeTeal" if won else &"BadgeRed"
	var opponent: PlayerData = player_match.opponent_of(player)
	var seed_number: int = tournament.seed_of(opponent)
	%OpponentLabel.text = opponent.short_name() + (" (%d)" % seed_number if seed_number > 0 else "")
	var index: int = player_match.players.find(player)
	var sets: PackedStringArray = []
	for games in player_match.set_games:
		sets.append("%d-%d" % [games[index], games[1 - index]])
	%ScoreLabel.text = " ".join(sets)
