## Songs the game plays in random order.
class_name MusicPlaylist
extends Resource

@export var tracks: Array[MusicTrack] = []


## A random track, other than `previous` when there is a choice.
func pick_random(previous: MusicTrack = null) -> MusicTrack:
	var candidates: Array[MusicTrack] = []
	for track in tracks:
		if track != previous:
			candidates.append(track)
	if candidates.is_empty():
		return tracks.pick_random()
	return candidates.pick_random()
