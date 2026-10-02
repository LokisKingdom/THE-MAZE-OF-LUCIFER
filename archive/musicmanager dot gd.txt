extends Node

const MUSIC_ROOT := "res://music/ALBUM ROOM/"

var current_song_path: String = ""
var current_song_title: String = ""

var player: AudioStreamPlayer
var library: Dictionary = {}

# A consistently ordered list of album names.
var album_names: Array[String] = []

var current_album_name: String = ""
var current_track_index: int = -1

# When enabled, next_track() selects a random song from the current album.
var random_mode: bool = true

# Keeps actual listening history so Previous works even in random mode.
var playback_history: Array[Dictionary] = []
var history_position: int = -1

signal song_changed(title: String)

func _ready() -> void:
	player = AudioStreamPlayer.new()
	add_child(player)
	
	# When a song ends naturally, move to the next song.
	player.finished.connect(next_track)

	print("MusicManager ready.")
	print("Scanning: ", MUSIC_ROOT)

	scan_library()

	print("Scan complete.")
	print("Albums found: ", library.size())
	print("Tracks found: ", get_track_count())

	if get_track_count() > 0:
		start_library()
	else:
		push_error("MusicManager found no playable music files.")


func _unhandled_input(event: InputEvent) -> void:
	# Avoid repeating commands while a key is held down.
	if event is InputEventKey and event.echo:
		return

	if event.is_action_pressed("music_next"):
		next_track()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("music_previous"):
		previous_track()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("music_random_toggle"):
		toggle_random_mode()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("music_play_pause"):
		toggle_play_pause()
		get_viewport().set_input_as_handled()


func scan_library() -> void:
	library.clear()
	album_names.clear()

	var physical_root := ProjectSettings.globalize_path(MUSIC_ROOT)

	print("Physical music path: ", physical_root)
	_scan_folder(physical_root)

	# Make album selection deterministic.
	album_names.assign(library.keys())
	album_names.sort()

	# Make song order deterministic within every album.
	for album_name in album_names:
		var tracks: Array = library[album_name]

		tracks.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return str(a["title"]).naturalnocasecmp_to(
					str(b["title"])
				) < 0
		)


func _scan_folder(folder_path: String) -> void:
	var directory := DirAccess.open(folder_path)

	if directory == null:
		push_error(
			"Could not open music folder: %s — error %s"
			% [folder_path, DirAccess.get_open_error()]
		)
		return

	directory.list_dir_begin()

	var file_name := directory.get_next()

	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = directory.get_next()
			continue

		var full_path := folder_path.path_join(file_name)

		if directory.current_is_dir():
			_scan_folder(full_path)

		elif _is_supported_audio_file(file_name):
			_add_track(full_path)

		file_name = directory.get_next()

	directory.list_dir_end()

func _is_supported_audio_file(file_name: String) -> bool:
	var extension := file_name.get_extension().to_lower()

	# Deepdive M4A files can remain excluded.
	return extension in ["mp3", "wav"]


func _add_track(full_path: String) -> void:
	var extension: String = (
		full_path.get_extension()
		.strip_edges()
		.to_lower()
	)

	if extension not in ["mp3", "wav"]:
		return

	var album_name := full_path.get_base_dir().get_file()

	if album_name.is_empty():
		album_name = "Unknown Album"

	var file_name := full_path.get_file()
	var song_title := file_name.get_basename()

	if not library.has(album_name):
		library[album_name] = []

	var track: Dictionary = {
		"title": song_title,
		"path": full_path,
		"album": album_name,
		"extension": extension
	}

	library[album_name].append(track)


func start_library() -> void:
	var playable_albums := get_playable_albums()

	if playable_albums.is_empty():
		push_error("No playable albums were found.")
		return

	# Begin with a random album.
	current_album_name = playable_albums.pick_random()

	var tracks: Array = library[current_album_name]

	if random_mode:
		current_track_index = randi_range(0, tracks.size() - 1)
	else:
		current_track_index = 0

	_play_current_track(true)


func next_track() -> void:
	if current_album_name.is_empty():
		start_library()
		return

	var tracks: Array = library.get(current_album_name, [])

	if tracks.is_empty():
		push_error("Current album contains no tracks.")
		return

	# If the user previously moved backward through history,
	# Next first moves forward through that existing history.
	if history_position < playback_history.size() - 1:
		history_position += 1

		var historical_track: Dictionary = playback_history[history_position]
		_set_current_track_from_dictionary(historical_track)
		_play_current_track(false)
		return

	if random_mode:
		current_track_index = _pick_different_random_index(
			tracks.size(),
			current_track_index
		)
	else:
		current_track_index = (current_track_index + 1) % tracks.size()

	_play_current_track(true)


func previous_track() -> void:
	if playback_history.is_empty():
		return

	# If the current song has played for several seconds,
	# restart it instead of jumping backward.
	if player.get_playback_position() > 4.0:
		player.play(0.0)
		print("Restarted current song.")
		return

	if history_position > 0:
		history_position -= 1

		var historical_track: Dictionary = playback_history[history_position]
		_set_current_track_from_dictionary(historical_track)
		_play_current_track(false)
	else:
		# At the beginning of history, restart the first song.
		player.play(0.0)


func toggle_random_mode() -> void:
	random_mode = not random_mode

	if random_mode:
		print("Album randomizer: ON")
	else:
		print("Album randomizer: OFF")


func toggle_play_pause() -> void:
	if player.stream == null:
		start_library()
		return

	if player.playing:
		player.stream_paused = true
		print("Music paused.")
	else:
		# If it was paused, unpause it.
		if player.stream_paused:
			player.stream_paused = false
			print("Music resumed.")
		else:
			# Stream exists but playback has stopped.
			player.play()
			print("Music started.")

func get_all_tracks() -> Array[Dictionary]:
	var all_tracks: Array[Dictionary] = []

	for album_name in album_names:
		var tracks: Array = library.get(album_name, [])

		for track_variant in tracks:
			var track: Dictionary = track_variant
			all_tracks.append(track.duplicate())

	all_tracks.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var album_comparison := str(a["album"]).naturalnocasecmp_to(
				str(b["album"])
			)

			if album_comparison != 0:
				return album_comparison < 0

			return str(a["title"]).naturalnocasecmp_to(
				str(b["title"])
			) < 0
	)

	return all_tracks

func play_track(track: Dictionary) -> void:
	if not track.has("path"):
		push_error("Track has no path.")
		return

	_set_current_track_from_dictionary(track)
	_play_current_track(true)


func _play_current_track(add_to_history: bool) -> void:
	var tracks: Array = library.get(current_album_name, [])

	if tracks.is_empty():
		push_error(
			"Cannot play from empty album: "
			+ current_album_name
		)
		return

	if (
		current_track_index < 0
		or current_track_index >= tracks.size()
	):
		push_error("Invalid track index.")
		return

	var track: Dictionary = tracks[current_track_index]
	var path: String = str(track["path"])

	var stream: AudioStream = _load_audio_stream(path)

	if stream == null:
		push_error("Failed to load audio file: " + path)

		# Skip files that truly cannot be loaded.
		call_deferred("next_track")
		return

	current_song_path = path
	current_song_title = str(track["title"])

	player.stop()
	player.stream = stream
	player.stream_paused = false
	player.play()

	if add_to_history:
		_add_to_history(track)

	song_changed.emit(current_song_title)

	print(
		"Playing %d/%d: %s from %s"
		% [
			current_track_index + 1,
			tracks.size(),
			track["title"],
			current_album_name
		]
	)

	print("File: ", path)

func _load_audio_stream(path: String) -> AudioStream:
	var extension: String = (
		path.get_extension()
		.strip_edges()
		.to_lower()
	)

	match extension:
		"mp3":
			return AudioStreamMP3.load_from_file(path)

		"wav":
			return AudioStreamWAV.load_from_file(path)

		_:
			push_error(
				"Unsupported audio extension '%s': %s"
				% [extension, path]
			)
			return null

func _add_to_history(track: Dictionary) -> void:
	# Moving backward and then selecting a new song creates
	# a new history branch, like a browser.
	if history_position < playback_history.size() - 1:
		playback_history.resize(history_position + 1)

	playback_history.append(track.duplicate())
	history_position = playback_history.size() - 1

	# Prevent an endless history array.
	const MAX_HISTORY := 500

	if playback_history.size() > MAX_HISTORY:
		playback_history.pop_front()
		history_position -= 1


func _set_current_track_from_dictionary(track: Dictionary) -> void:
	var album_name := str(track.get("album", ""))

	if not library.has(album_name):
		push_error("Track album is no longer available: " + album_name)
		return

	var tracks: Array = library[album_name]
	var track_path := str(track.get("path", ""))

	for index in range(tracks.size()):
		if str(tracks[index]["path"]) == track_path:
			current_album_name = album_name
			current_track_index = index
			return

	push_error("Could not locate track in library: " + track_path)


func _pick_different_random_index(
	track_count: int,
	old_index: int
) -> int:
	if track_count <= 1:
		return 0

	var new_index := old_index

	while new_index == old_index:
		new_index = randi_range(0, track_count - 1)

	return new_index


func get_playable_albums() -> Array[String]:
	var playable_albums: Array[String] = []

	for album_name in album_names:
		var tracks: Array = library[album_name]

		if not tracks.is_empty():
			playable_albums.append(album_name)

	return playable_albums


func select_album(album_name: String) -> void:
	if not library.has(album_name):
		push_error("Unknown album: " + album_name)
		return

	var tracks: Array = library[album_name]

	if tracks.is_empty():
		push_error("Album contains no playable tracks: " + album_name)
		return

	current_album_name = album_name

	if random_mode:
		current_track_index = randi_range(0, tracks.size() - 1)
	else:
		current_track_index = 0

	_play_current_track(true)


func get_current_track() -> Dictionary:
	if current_album_name.is_empty():
		return {}

	var tracks: Array = library.get(current_album_name, [])

	if current_track_index < 0 or current_track_index >= tracks.size():
		return {}

	return tracks[current_track_index]


func get_track_count() -> int:
	var total := 0

	for tracks in library.values():
		total += tracks.size()

	return total


func play_random_song() -> String:
	var playable_albums := get_playable_albums()

	if playable_albums.is_empty():
		push_error("Cannot select a random song: no playable albums.")
		return ""

	current_album_name = playable_albums.pick_random()

	var tracks: Array = library.get(current_album_name, [])

	if tracks.is_empty():
		push_error(
			"Randomly selected album has no tracks: "
			+ current_album_name
		)
		return ""

	current_track_index = randi_range(0, tracks.size() - 1)

	_play_current_track(true)

	return current_song_title


func get_current_song_title() -> String:
	return current_song_title
