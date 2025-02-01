extends HBoxContainer

@onready var info = $Info
@onready var player_name = info.get_node("Name")
@onready var rank = info.get_node("Hbox/Rank")
@onready var player_image = $PlayerImage
