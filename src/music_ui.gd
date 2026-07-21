extends Node


@onready var album_selector: OptionButton = %AlbumSelector
@onready var current_song_selector: OptionButton = %CurrentSongSelector


var song_selector_tracks: Array[Dictionary] = []
var updating_album_selector := false
var updating_song_selector := false


func _ready() -> void:
	_connect_signals()
	_populate_album_selector()
	_sync_interface_to_current_song()


func _connect_signals() -> void:
	if not album_selector.item_selected.is_connected(
		_on_album_selected
	):
		album_selector.item_selected.connect(
			_on_album_selected
		)

	if not current_song_selector.item_selected.is_connected(
		_on_song_selected
	):
		current_song_selector.item_selected.connect(
			_on_song_selected
		)

	if not MusicManager.song_changed.is_connected(
		_on_music_song_changed
	):
		MusicManager.song_changed.connect(
			_on_music_song_changed
		)


func _populate_album_selector() -> void:
	if album_selector == null:
		push_error(
			"Gameplay AlbumSelector could not be found."
		)
		return

	updating_album_selector = true
	album_selector.clear()

	var albums: Array = MusicManager.library.keys()
	albums.sort_custom(
		func(a: Variant, b: Variant) -> bool:
			return str(a).naturalnocasecmp_to(str(b)) < 0
	)

	for album in albums:
		album_selector.add_item(str(album))

	updating_album_selector = false

	_select_current_album()


func _populate_song_selector(album_name: String) -> void:
	if current_song_selector == null:
		push_error(
			"Gameplay CurrentSongSelector could not be found."
		)
		return

	updating_song_selector = true

	current_song_selector.clear()
	song_selector_tracks.clear()

	if album_name.is_empty():
		current_song_selector.add_item("No album selected")
		current_song_selector.disabled = true
		updating_song_selector = false
		return

	if not MusicManager.library.has(album_name):
		current_song_selector.add_item("Album unavailable")
		current_song_selector.disabled = true
		updating_song_selector = false
		return

	var tracks: Array = MusicManager.library.get(
		album_name,
		[]
	)

	if tracks.is_empty():
		current_song_selector.add_item(
			"No playable songs"
		)
		current_song_selector.disabled = true
		updating_song_selector = false
		return

	current_song_selector.disabled = false

	for track_variant in tracks:
		var track: Dictionary = track_variant
		song_selector_tracks.append(track)

		var title := str(
			track.get("title", "Unknown Song")
		)

		current_song_selector.add_item(title)

	updating_song_selector = false

	_select_current_song()


func _select_current_album() -> void:
	if MusicManager.current_album_name.is_empty():
		return

	updating_album_selector = true

	for index in range(album_selector.item_count):
		if (
			album_selector.get_item_text(index)
			== MusicManager.current_album_name
		):
			album_selector.select(index)
			break

	updating_album_selector = false


func _select_current_song() -> void:
	if song_selector_tracks.is_empty():
		return

	var current_path: String = (
		MusicManager.current_song_path
	)

	if current_path.is_empty():
		return

	updating_song_selector = true

	for index in range(song_selector_tracks.size()):
		var track: Dictionary = (
			song_selector_tracks[index]
		)

		var track_path := str(
			track.get("path", "")
		)

		if track_path == current_path:
			current_song_selector.select(index)
			break

	updating_song_selector = false


func _sync_interface_to_current_song() -> void:
	_select_current_album()

	_populate_song_selector(
		MusicManager.current_album_name
	)

	_select_current_song()


func _on_album_selected(index: int) -> void:
	if updating_album_selector:
		return

	if index < 0 or index >= album_selector.item_count:
		return

	var album_name := album_selector.get_item_text(
		index
	)

	# This selects the album and starts one of its songs.
	MusicManager.select_album(album_name)

	# Refresh the song list for the newly selected album.
	_populate_song_selector(album_name)


func _on_song_selected(index: int) -> void:
	if updating_song_selector:
		return

	if index < 0 or index >= song_selector_tracks.size():
		return

	var selected_track: Dictionary = (
		song_selector_tracks[index]
	)

	MusicManager.play_track(selected_track)


func _on_music_song_changed(_title: String) -> void:
	# Songs can change from:
	# - Start Game
	# - stairs
	# - Next or Previous
	# - automatic playback
	# - album selection
	#
	# Re-synchronize both dropdowns with the song
	# MusicManager is actually playing.

	var album_changed := (
		MusicManager.current_album_name
		!= _get_selected_album_name()
	)

	_select_current_album()

	if album_changed:
		_populate_song_selector(
			MusicManager.current_album_name
		)
	else:
		_select_current_song()


func _get_selected_album_name() -> String:
	if album_selector.item_count == 0:
		return ""

	var selected_index := album_selector.selected

	if (
		selected_index < 0
		or selected_index >= album_selector.item_count
	):
		return ""

	return album_selector.get_item_text(
		selected_index
	)
