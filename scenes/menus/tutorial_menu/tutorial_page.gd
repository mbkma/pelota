## A page of the how-to-play tutorial.
class_name TutorialPage
extends Resource

@export var title: String
@export_multiline var text: String
@export var image: Texture2D
@export var controls: Array[TutorialControl] = []
