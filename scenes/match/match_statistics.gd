## Match statistics of one player, recorded by the MatchManager.
class_name MatchStatistics
extends RefCounted

var aces: int = 0
var double_faults: int = 0
var first_serves_in: int = 0
var first_serves_total: int = 0
var first_serve_points_won: int = 0
var first_serve_points_played: int = 0
var second_serve_points_won: int = 0
var second_serve_points_played: int = 0
var fastest_serve_kmh: float = 0.0
var _first_serve_speed_sum_kmh: float = 0.0
var _first_serve_speed_count: int = 0
var break_points_won: int = 0
var break_points_played: int = 0
var break_points_saved: int = 0
var break_points_faced: int = 0
var winners: int = 0
var errors: int = 0
var net_points_won: int = 0
var net_points_played: int = 0
var total_points_won: int = 0
## Distance covered on court (m)
var distance_covered: float = 0.0


func record_serve_speed(speed_kmh: float, is_first_serve: bool) -> void:
	fastest_serve_kmh = maxf(fastest_serve_kmh, speed_kmh)
	if is_first_serve:
		_first_serve_speed_sum_kmh += speed_kmh
		_first_serve_speed_count += 1


func average_first_serve_kmh() -> float:
	if _first_serve_speed_count == 0:
		return 0.0
	return _first_serve_speed_sum_kmh / _first_serve_speed_count

