class_name Track
extends Resource

var title: String
var artist: String
var stream: AudioStream
var cover_path: String


func _init(title, artist, stream, cover_path) -> void:
	self.title = title
	self.artist = artist
	self.stream = stream
	self.cover_path = cover_path
