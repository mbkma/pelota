class_name StrokeSelector
extends RefCounted


func choose_candidate(candidates: Array, context: AiPointContext, stats: PlayerRuntimeStats, play_style: PlayStyleProfile):
	if candidates.is_empty():
		return null

	var weighted_pool: Array = []
	var total_weight: float = 0.0
	for entry in candidates:
		if not entry:
			continue
		var candidate = entry
		var weight: float = exp(candidate.score * 2.2)
		if play_style:
			weight *= lerpf(0.9, 1.1, play_style.variety)
		if context and context.is_serve:
			weight *= 1.15
		if stats:
			weight *= lerpf(0.9, 1.08, stats.pressure_resistance01())
		weighted_pool.append({"candidate": candidate, "weight": weight})
		total_weight += weight

	if weighted_pool.is_empty():
		return null

	var roll: float = randf() * total_weight
	for entry in weighted_pool:
		roll -= entry.weight
		if roll <= 0.0:
			return entry.candidate

	return weighted_pool.back().candidate