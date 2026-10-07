## Global debug logger for game events and state changes, shown in the debug HUD.
## Any object can call DebugLogger.log(self, message); a "logger_name" meta names the sender.
extends Node

const MAX_LOG_ENTRIES: int = 1000

## Entries {timestamp, object_name, message}, oldest first
var _log_buffer: Array[Dictionary] = []
var _log_start_time_ms: int = 0


func _ready() -> void:
	_log_start_time_ms = Time.get_ticks_msec()


func log(sender: Object, message: String) -> void:
	var fallback_name: String = String(sender.name) if sender is Node else sender.get_class()
	var object_name: String = sender.get_meta("logger_name", fallback_name)
	_log_buffer.append(
		{"timestamp": Time.get_ticks_msec(), "object_name": object_name, "message": message}
	)
	if _log_buffer.size() > MAX_LOG_ENTRIES:
		_log_buffer.pop_front()


func get_logs() -> Array[Dictionary]:
	return _log_buffer.duplicate()


## Start time for relative timestamps
func get_start_time_ms() -> int:
	return _log_start_time_ms


func clear_logs() -> void:
	_log_buffer.clear()
