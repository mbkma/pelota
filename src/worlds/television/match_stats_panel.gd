extends Control

var players

@onready var name_label1 = $Panel/Label
@onready var name_label2 = $Panel/Label2

@onready var image1 = $PlayerImage
@onready var image2 = $PlayerImage2

@onready var anim_player = $AnimationPlayer

const SPRITE_PATH: String = "res://assets/images/players/"


func setup_singles_match(singles_match: SinglesMatch):
	players = singles_match.players
	set_players(singles_match.players[0], singles_match.players[1])
	anim_player.play("start")


func set_players(player1, player2):
	name_label1.text = player1.player_data.first_name + "\n" + player1.player_data.last_name
	if ResourceLoader.exists(SPRITE_PATH + player1.player_data["last_name"].to_lower() + ".png"):
		image1.texture = load(SPRITE_PATH + player1.player_data["last_name"].to_lower() + ".png")

	name_label2.text = player2.player_data.first_name + "\n" + player2.player_data.last_name
	if ResourceLoader.exists(SPRITE_PATH + player2.player_data["last_name"].to_lower() + ".png"):
		image2.texture = load(SPRITE_PATH + player2.player_data["last_name"].to_lower() + ".png")
