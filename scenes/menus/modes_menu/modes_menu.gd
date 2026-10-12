## The game modes beyond a single match, opened by the main menu's 'Modes' button: the tournament
## (continuing a saved one too) and the training. The main menu opens the mode picked.
class_name ModesMenu
extends Control

signal tournament_requested
signal continue_tournament_requested
signal training_requested

@onready var _continue_button: Button = %ContinueTournamentButton
@onready var _tournament_button: Button = %TournamentButton
@onready var _training_button: Button = %TrainingButton
@onready var _back_button: Button = %BackButton


## Shows the continue button when there is a saved tournament.
func setup(has_saved_tournament: bool) -> void:
	_continue_button.visible = has_saved_tournament
	_continue_button.text = "Continue %s" % Tournament.NAME
	_tournament_button.text = Tournament.NAME


func _ready() -> void:
	_continue_button.pressed.connect(continue_tournament_requested.emit)
	_tournament_button.pressed.connect(tournament_requested.emit)
	_training_button.pressed.connect(training_requested.emit)
	_back_button.pressed.connect(queue_free)
	(_continue_button if _continue_button.visible else _tournament_button).grab_focus()
