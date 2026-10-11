class_name CrowdAudioConfig
extends Resource
## Sounds of the crowd.

## Background crowd noise between and during points, played one after another
@export var idle_sounds: Array[AudioStream] = []
## Background crowd noise during the changeover after a set, played over and over
@export var changeover_sound: AudioStream
## Applause after a point: short for an ordinary point, medium and big for exciting ones
@export var short_cheers: Array[AudioStream] = []
@export var medium_cheers: Array[AudioStream] = []
@export var big_cheers: Array[AudioStream] = []
