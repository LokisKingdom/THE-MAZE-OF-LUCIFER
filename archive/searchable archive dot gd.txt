extends Control
class_name SearchableArchive


# This should point to the same folder scanned by NoteLibrary.gd.
@export_dir var archive_root: String = "res://music/DECLASSIFIED"

# Hide the archive when the game starts.
@export var start_hidden: bool = true

# Maximum amount of text added to the search index from one document.
@export var max_indexed_text_bytes: int = 2_000_000


# -------------------------------------------------------------------
# ARCHIVE DATA
# -------------------------------------------------------------------

# Entries currently unlocked by the player.
var entries: Array[Dictionary] = []

# Entries currently visible after applying search and folder filters.
var shown: Array[Dictionary] = []

# Entry currently open in the reader.
var current: Dictionary = {}

# Text display scale.
var zoom: float = 1.0
const BASE_FONT_SIZE: int = 18


# -------------------------------------------------------------------
# GENERATED UI REFERENCES
# -------------------------------------------------------------------

var search: LineEdit
var folders: OptionButton
var results: Label
var files: ItemList
var title: Label
var status: Label
var text_view: RichTextLabel
var zoom_label: Label
@onready var music_ui: CanvasLayer = (
	get_tree().get_first_node_in_group("MusicUI") as CanvasLayer
)


# -------------------------------------------------------------------
# FUNCTION: _ready()
# -------------------------------------------------------------------

func _ready() -> void:
	_build_ui()
	_ensure_action()

	await rebuild_archive()

	visible = not start_hidden


# -------------------------------------------------------------------
# FUNCTION: _unhandled_input()
# -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("archive_toggle"):
		toggle_archive()
		get_viewport().set_input_as_handled()

	elif visible and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()


# -------------------------------------------------------------------
# FUNCTION: toggle_archive()
#
# Opens or closes the archive.
# Refreshes the archive whenever it opens, so newly collected notes
# appear immediately.
# -------------------------------------------------------------------

func toggle_archive() -> void:
	if visible:
		close_archive()
	else:
		await open_archive()


# -------------------------------------------------------------------
# FUNCTION: open_archive()
#
# Can be called by another script or button.
# -------------------------------------------------------------------

func open_archive() -> void:
	music_ui.hide()
	await rebuild_archive()
	show()
	search.grab_focus()


# -------------------------------------------------------------------
# FUNCTION: close_archive()
# -------------------------------------------------------------------

func close_archive() -> void:
	hide()
	music_ui.show()


# -------------------------------------------------------------------
# FUNCTION: rebuild_archive()
#
# IMPORTANT:
# This function does not scan archive_root.
#
# It only loads documents already present in:
# NoteLibrary.unlocked_notes
# -------------------------------------------------------------------

func rebuild_archive() -> void:
	entries.clear()
	current.clear()

	status.text = "Loading discovered notes..."

	await get_tree().process_frame

	for unlocked_note: Dictionary in NoteLibrary.unlocked_notes:
		var entry: Dictionary = _entry_from_unlocked_note(unlocked_note)

		if not entry.is_empty():
			entries.append(entry)

	entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return String(a["relative"]).naturalnocasecmp_to(
				String(b["relative"])
			) < 0
	)

	_rebuild_folder_list()
	_filter()

	if entries.is_empty():
		status.text = "No notes have been discovered."
	else:
		status.text = "Archive ready: %d discovered note%s." % [
			entries.size(),
			"" if entries.size() == 1 else "s"
		]


# -------------------------------------------------------------------
# FUNCTION: _entry_from_unlocked_note()
#
# Converts a NoteLibrary entry into the format used by this window.
#
# Expected NoteLibrary structure:
#
# {
#     "title": "Document Name",
#     "file": "res://music/DECLASSIFIED/Document Name.txt"
# }
# -------------------------------------------------------------------

func _entry_from_unlocked_note(note: Dictionary) -> Dictionary:
	if not note.has("file"):
		push_warning("Unlocked note has no file path: " + str(note))
		return {}

	var path: String = str(note["file"])

	if path.is_empty():
		return {}

	if not FileAccess.file_exists(path):
		push_warning("Unlocked note file is missing: " + path)
		return {}

	if path.get_extension().to_lower() != "txt":
		# This collectible archive is intentionally text-only.
		return {}

	var relative: String = path.trim_prefix(archive_root).trim_prefix("/")

	# If the file is outside archive_root, use its filename instead.
	if relative == path:
		relative = path.get_file()

	var folder: String = relative.get_base_dir()

	if folder == "." or folder.is_empty():
		folder = "(ROOT)"

	var display_name: String

	if note.has("title") and not str(note["title"]).is_empty():
		display_name = str(note["title"])
	else:
		display_name = path.get_file().get_basename().replace("_", " ")

	var searchable: String = "%s %s %s" % [
		display_name,
		relative,
		folder
	]

	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)

	if bytes.size() > max_indexed_text_bytes:
		bytes = bytes.slice(0, max_indexed_text_bytes)

	searchable += " " + bytes.get_string_from_utf8()

	return {
		"title": display_name,
		"path": path,
		"relative": relative,
		"folder": folder,
		"search": searchable.to_lower()
	}


# -------------------------------------------------------------------
# FUNCTION: _filter()
#
# Applies the search text and selected folder.
# -------------------------------------------------------------------

func _filter(_unused = null) -> void:
	shown.clear()
	files.clear()

	var query: String = search.text.strip_edges().to_lower()
	var wanted_folder: String = folders.get_item_text(folders.selected)

	for entry: Dictionary in entries:
		var entry_folder: String = str(entry["folder"])
		var entry_search: String = str(entry["search"])

		var folder_matches: bool = (
			wanted_folder == "ALL FOLDERS"
			or entry_folder == wanted_folder
		)

		var search_matches: bool = (
			query.is_empty()
			or entry_search.contains(query)
		)

		if folder_matches and search_matches:
			shown.append(entry)

			files.add_item(
				"%s  [TXT]" % str(entry["relative"])
			)

	results.text = "%d result%s" % [
		shown.size(),
		"" if shown.size() == 1 else "s"
	]

	if shown.is_empty():
		if entries.is_empty():
			_clear(
				"NO NOTES DISCOVERED\n\n"
				+ "Documents found throughout the world will appear here."
			)
		else:
			_clear("No discovered notes match the current search.")
		return

	files.select(0)
	_open(shown[0])


# -------------------------------------------------------------------
# FUNCTION: _open_selected()
# -------------------------------------------------------------------

func _open_selected(index: int) -> void:
	if index < 0 or index >= shown.size():
		return

	_open(shown[index])


# -------------------------------------------------------------------
# FUNCTION: _open()
#
# Opens one unlocked text document.
# -------------------------------------------------------------------

func _open(entry: Dictionary) -> void:
	if entry.is_empty():
		return

	current = entry

	title.text = str(entry["title"])
	status.text = str(entry["relative"])

	var path: String = str(entry["path"])

	if not FileAccess.file_exists(path):
		_clear("The discovered document could not be found.")
		return

	text_view.text = FileAccess.get_file_as_bytes(path).get_string_from_utf8()
	text_view.scroll_to_line(0)


# -------------------------------------------------------------------
# FUNCTION: _clear()
# -------------------------------------------------------------------

func _clear(message: String) -> void:
	current.clear()
	title.text = "SEARCHABLE ARCHIVE"
	status.text = message
	text_view.text = ""


# -------------------------------------------------------------------
# FUNCTION: _rebuild_folder_list()
# -------------------------------------------------------------------

func _rebuild_folder_list() -> void:
	var previous_folder: String = "ALL FOLDERS"

	if folders.item_count > 0 and folders.selected >= 0:
		previous_folder = folders.get_item_text(folders.selected)

	var unique_folders: Array[String] = []

	for entry: Dictionary in entries:
		var folder: String = str(entry["folder"])

		if not unique_folders.has(folder):
			unique_folders.append(folder)

	unique_folders.sort()

	folders.clear()
	folders.add_item("ALL FOLDERS")

	for folder: String in unique_folders:
		folders.add_item(folder)

	var new_selection: int = 0

	for index: int in range(folders.item_count):
		if folders.get_item_text(index) == previous_folder:
			new_selection = index
			break

	folders.select(new_selection)


# -------------------------------------------------------------------
# FUNCTION: _zoom_in()
#
# Enlarges the text.
# -------------------------------------------------------------------

func _zoom_in() -> void:
	zoom = minf(3.0, zoom + 0.1)
	_apply_zoom()


# -------------------------------------------------------------------
# FUNCTION: _zoom_out()
#
# Shrinks the text.
# -------------------------------------------------------------------

func _zoom_out() -> void:
	zoom = maxf(0.5, zoom - 0.1)
	_apply_zoom()


# -------------------------------------------------------------------
# FUNCTION: _reset_zoom()
# -------------------------------------------------------------------

func _reset_zoom() -> void:
	zoom = 1.0
	_apply_zoom()


# -------------------------------------------------------------------
# FUNCTION: _apply_zoom()
# -------------------------------------------------------------------

func _apply_zoom() -> void:
	var font_size: int = maxi(
		8,
		int(round(float(BASE_FONT_SIZE) * zoom))
	)

	text_view.add_theme_font_size_override(
		"normal_font_size",
		font_size
	)

	_update_zoom()


# -------------------------------------------------------------------
# FUNCTION: _update_zoom()
# -------------------------------------------------------------------

func _update_zoom() -> void:
	if zoom_label != null:
		zoom_label.text = "%d%%" % int(round(zoom * 100.0))


# -------------------------------------------------------------------
# FUNCTION: _ensure_action()
#
# Creates the F6 archive shortcut when it is not already defined.
# -------------------------------------------------------------------

func _ensure_action() -> void:
	if InputMap.has_action("archive_toggle"):
		return

	InputMap.add_action("archive_toggle")

	var key := InputEventKey.new()
	key.physical_keycode = KEY_F6

	InputMap.action_add_event("archive_toggle", key)


# -------------------------------------------------------------------
# FUNCTION: _build_ui()
#
# Builds the Searchable Archive interface.
# -------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var background := ColorRect.new()
	background.color = Color(0.025, 0.025, 0.03, 0.985)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 8)
	margin.add_child(main)

	# ---------------------------------------------------------------
	# TOP BAR
	# ---------------------------------------------------------------

	var top := HBoxContainer.new()
	main.add_child(top)

	var heading := Label.new()
	heading.text = "SEARCHABLE ARCHIVE"
	heading.add_theme_font_size_override("font_size", 24)
	top.add_child(heading)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	var refresh_button := Button.new()
	refresh_button.text = "REFRESH DISCOVERED NOTES"
	refresh_button.pressed.connect(rebuild_archive)
	top.add_child(refresh_button)

	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.pressed.connect(close_archive)
	top.add_child(close_button)

	# ---------------------------------------------------------------
	# FILTER BAR
	# ---------------------------------------------------------------

	var filter_row := HBoxContainer.new()
	main.add_child(filter_row)

	search = LineEdit.new()
	search.placeholder_text = "Search discovered filenames and TXT contents..."
	search.clear_button_enabled = true
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(_filter)
	filter_row.add_child(search)

	folders = OptionButton.new()
	folders.custom_minimum_size.x = 190
	folders.add_item("ALL FOLDERS")
	folders.item_selected.connect(_filter)
	filter_row.add_child(folders)

	results = Label.new()
	results.custom_minimum_size.x = 90
	results.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	filter_row.add_child(results)

	# ---------------------------------------------------------------
	# FILE LIST AND READER
	# ---------------------------------------------------------------

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 350
	main.add_child(split)

	files = ItemList.new()
	files.custom_minimum_size.x = 260
	files.size_flags_vertical = Control.SIZE_EXPAND_FILL
	files.item_selected.connect(_open_selected)
	files.item_activated.connect(_open_selected)
	split.add_child(files)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size = Vector2.ZERO
	right.clip_contents = true
	split.add_child(right)

	title = Label.new()
	title.text = "SEARCHABLE ARCHIVE"
	title.add_theme_font_size_override("font_size", 22)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(title)

	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(status)

	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(frame)

	text_view = RichTextLabel.new()
	text_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_view.custom_minimum_size = Vector2.ZERO
	text_view.fit_content = false
	text_view.scroll_active = true
	text_view.scroll_following = false
	text_view.selection_enabled = true
	text_view.context_menu_enabled = true
	text_view.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	frame.add_child(text_view)

	# ---------------------------------------------------------------
	# TEXT ZOOM CONTROLS
	# ---------------------------------------------------------------

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(controls)

	var minus := Button.new()
	minus.text = "-"
	minus.pressed.connect(_zoom_out)
	controls.add_child(minus)

	zoom_label = Label.new()
	zoom_label.custom_minimum_size.x = 70
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_child(zoom_label)

	var plus := Button.new()
	plus.text = "+"
	plus.pressed.connect(_zoom_in)
	controls.add_child(plus)

	var reset := Button.new()
	reset.text = "RESET TEXT SIZE"
	reset.pressed.connect(_reset_zoom)
	controls.add_child(reset)

	_apply_zoom()
