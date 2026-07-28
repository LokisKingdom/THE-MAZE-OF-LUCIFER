extends Node


var NOTES_FOLDER := ""

var all_notes: Array[Dictionary] = []
var unlocked_notes: Array[Dictionary] = []

var rng := RandomNumberGenerator.new()


# ------------------------------------------------------------
# FUNCTION: _ready()
# ------------------------------------------------------------

func _ready() -> void:
	NOTES_FOLDER = OS.get_executable_path().get_base_dir().path_join(
		"music/DECLASSIFIED/"
	)

	print("Notes folder: ", NOTES_FOLDER)

	rng.randomize()
	load_all_notes()


# ------------------------------------------------------------
# FUNCTION: load_all_notes()
#
# Finds every .txt file inside res://notes/
# ------------------------------------------------------------

func load_all_notes() -> void:
	all_notes.clear()

	var directory := DirAccess.open(NOTES_FOLDER)

	if directory == null:
		push_error(
			"Could not open notes folder: %s" % NOTES_FOLDER
		)
		return

	directory.list_dir_begin()

	var file_name := directory.get_next()

	while file_name != "":
		if (
			not directory.current_is_dir()
			and file_name.to_lower().ends_with(".txt")
		):
			var file_path := NOTES_FOLDER.path_join(file_name)

			all_notes.append({
				"title": file_name.get_basename(),
				"file": file_path,
			})

		file_name = directory.get_next()

	directory.list_dir_end()

	print(
		"Loaded %d possible notes from %s"
		% [
			all_notes.size(),
			NOTES_FOLDER,
		]
	)


# ------------------------------------------------------------
# FUNCTION: unlock_random_note()
#
# Selects one random note that has not already been unlocked.
# ------------------------------------------------------------

func unlock_random_note() -> Dictionary:
	var locked_notes: Array[Dictionary] = []

	for note: Dictionary in all_notes:
		var file_path := str(note.get("file", ""))

		if not is_note_unlocked(file_path):
			locked_notes.append(note)

	if locked_notes.is_empty():
		print(
			"No locked notes remain. Total notes: %d, unlocked: %d"
			% [
				all_notes.size(),
				unlocked_notes.size(),
			]
		)

		return {}

	var random_index := rng.randi_range(
		0,
		locked_notes.size() - 1
	)

	var unlocked_note: Dictionary = locked_notes[random_index].duplicate(
		true
	)

	unlocked_notes.append(unlocked_note)

	print(
		"Unlocked note: %s"
		% str(unlocked_note.get("title", "Unknown Note"))
	)

	return unlocked_note


# ------------------------------------------------------------
# FUNCTION: is_note_unlocked()
# ------------------------------------------------------------

func is_note_unlocked(file_path: String) -> bool:
	for note: Dictionary in unlocked_notes:
		if str(note.get("file", "")) == file_path:
			return true

	return false


# ------------------------------------------------------------
# FUNCTION: read_note()
# ------------------------------------------------------------

func read_note(note: Dictionary) -> String:
	if note.is_empty():
		return ""

	var file_path := str(note.get("file", ""))

	if file_path.is_empty():
		push_error("The note does not contain a file path.")
		return "This document could not be opened."

	if not FileAccess.file_exists(file_path):
		push_error("Note file does not exist: %s" % file_path)
		return "This document could not be found."

	var file := FileAccess.open(
		file_path,
		FileAccess.READ
	)

	if file == null:
		push_error("Could not read note: %s" % file_path)
		return "This document could not be opened."

	return file.get_as_text()
