## Global utility functions for game logic and calculations
extends Node


## Get horizontal distance from source to target in XZ plane
func get_horizontal_distance(source: Node3D, target: Node3D) -> float:
	if not source or not target:
		return 0.0

	# Calculate the direction to the target in the XZ plane
	var direction_to_target: Vector3 = target.position - source.position
	direction_to_target.y = 0  # Ignore the vertical component

	# Calculate and return the horizontal distance
	return direction_to_target.length()


## Get all file paths in a directory with optional extension filter
func get_filepaths_in_directory(directory_path: String, ending: String = "") -> Array[String]:
	var filepaths: Array[String] = []
	var dir: DirAccess = DirAccess.open(directory_path)

	# Open the directory
	if dir != null:
		# List files and directories, including hidden ones
		dir.list_dir_begin()

		var file_name: String = dir.get_next()
		while file_name != "":
			# Skip the current directory (".") and parent directory ("..")
			if file_name == "." or file_name == "..":
				file_name = dir.get_next()
				continue

			# Check if it's a directory or a file, and filter by extension
			if dir.current_is_dir():
				pass
			elif ending != "" and file_name.ends_with(ending):
				filepaths.append(directory_path + "/" + file_name)
			elif ending == "":
				filepaths.append(directory_path + "/" + file_name)

			file_name = dir.get_next()
		dir.list_dir_end()  # End directory listing
	else:
		push_error("Error accessing directory path: " + directory_path)

	return filepaths
