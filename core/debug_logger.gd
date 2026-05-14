## Global singleton debug logger for game events and state changes
## Any Godot object can call DebugLogger.log(self, message) to send messages
extends Node

## Log entry structure: {timestamp, object, object_name, message}
var _log_buffer: Array[Dictionary] = []
const MAX_LOG_ENTRIES: int = 1000
var _log_start_time_ms: int = 0
var _last_object_names_count: int = 0


func _ready() -> void:
	_log_start_time_ms = Time.get_ticks_msec()
	print("DebugLogger initialized")


## Log a message from any object
func log(sender: Object, message: String) -> void:
	var object_name: String = "Unknown"
	
	if sender:
		# Try to get a meaningful name from the object
		if sender.has_meta("logger_name"):
			object_name = sender.get_meta("logger_name")
		elif "player_data" in sender and sender.player_data and "last_name" in sender.player_data:
			object_name = sender.player_data.last_name
		else:
			object_name = sender.name if sender.name else sender.get_class()
	
	var entry: Dictionary = {
		"timestamp": Time.get_ticks_msec(),
		"object": sender,
		"object_name": object_name,
		"message": message
	}
	
	_log_buffer.append(entry)
	
	# Maintain max log size
	if _log_buffer.size() > MAX_LOG_ENTRIES:
		_log_buffer.pop_front()


## Get all log entries
func get_logs() -> Array[Dictionary]:
	return _log_buffer.duplicate()


## Get start time for relative timestamps
func get_start_time_ms() -> int:
	return _log_start_time_ms


## Clear all logs
func clear_logs() -> void:
	_log_buffer.clear()


## Get unique object names from logs in order they first appeared
func get_object_names() -> PackedStringArray:
	var names: PackedStringArray = []
	var seen: Dictionary = {}
	
	for entry in _log_buffer:
		var obj_name: String = entry["object_name"]
		if not seen.has(obj_name):
			seen[obj_name] = true
			names.append(obj_name)
	
	return names


## Check if object names have changed (for detecting when to refresh dropdown)
func have_object_names_changed() -> bool:
	var current_count = get_object_names().size()
	var changed = current_count != _last_object_names_count
	_last_object_names_count = current_count
	return changed
