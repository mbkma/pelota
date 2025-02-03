extends Node

#const MainMenuScene = "res://src/menus/main-menu.tscn"
#const MatchScene = "res://src/match/match.tscn"
const BALL = preload("res://src/ball.tscn")

enum {
	SIDE0 = 0,
	SIDE1 = 1,
}

enum {
	OUT = 0,
	DEUCE_FIELD,
	AD_FIELD,
}

enum MatchStates {
	IDLE = 0,
	SERVE = 1,
	SECOND_SERVE = 2,
	PLAY = 3,
	FAULT = 4,
}

const DEBUGGING = false


func get_filepaths_in_directory(directory_path: String, ending: String = "") -> Array:
	var filepaths := []
	var dir = DirAccess.open(directory_path)

	# Open the directory
	if dir != null:
		# List files and directories, including hidden ones
		dir.list_dir_begin()

		var file_name = dir.get_next()
		while file_name != "":
			# Skip the current directory (".") and parent directory ("..")
			if file_name == "." or file_name == "..":
				file_name = dir.get_next()
				continue

			# Check if it's a directory or a file, and filter by extension
			if dir.current_is_dir():
				print("Found directory: " + file_name)
			elif ending != "" and file_name.ends_with(ending):
				filepaths.append(directory_path + "/" + file_name)
			elif ending == "":
				filepaths.append(directory_path + "/" + file_name)

			file_name = dir.get_next()
		dir.list_dir_end()  # End directory listing
	else:
		print("An error occurred when trying to access the path.")

	return filepaths


func spin_to_gravity(spin: float) -> float:
	return 10 + spin


func get_opposite_side(side) -> int:
	return SIDE1 if side == SIDE0 else SIDE0
