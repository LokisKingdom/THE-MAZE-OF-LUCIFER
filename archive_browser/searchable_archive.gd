extends Control
class_name SearchableArchive

@export_dir var archive_root := "res://music/DECLASSIFIED"
@export var start_hidden := true
@export var max_indexed_text_bytes := 2_000_000

var entries: Array[Dictionary] = []
var shown: Array[Dictionary] = []
var current: Dictionary = {}
var zoom := 1.0

var search: LineEdit
var folders: OptionButton
var types: OptionButton
var results: Label
var files: ItemList
var title: Label
var status: Label
var text_view: RichTextLabel
var image_scroll: ScrollContainer
var image_view: TextureRect
var pdf_box: VBoxContainer
var pdf_info: Label
var zoom_label: Label

func _ready() -> void:
	_build_ui()
	_ensure_action()
	await rebuild_archive()
	visible = not start_hidden

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("archive_toggle"):
		toggle_archive()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()

func toggle_archive() -> void:
	visible = not visible
	if visible:
		search.grab_focus()

func rebuild_archive() -> void:
	entries.clear()
	status.text = "Scanning archive..."
	await get_tree().process_frame
	_scan(archive_root)
	entries.sort_custom(func(a, b): return String(a.path).naturalnocasecmp_to(String(b.path)) < 0)
	_rebuild_folder_list()
	_filter()
	status.text = "Archive ready: %d files indexed." % entries.size()

func _scan(folder: String) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		push_warning("Archive folder missing: " + folder)
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var full := folder.path_join(name)
			if dir.current_is_dir():
				_scan(full)
			else:
				var ext := name.get_extension().to_lower()
				if ext in ["txt", "pdf", "jpg", "jpeg", "png", "webp"]:
					entries.append(_entry(full, ext))
		name = dir.get_next()
	dir.list_dir_end()

func _entry(path: String, ext: String) -> Dictionary:
	var rel := path.trim_prefix(archive_root).trim_prefix("/")
	var folder := rel.get_base_dir()
	if folder == ".":
		folder = "(ROOT)"
	var display_name := path.get_file().get_basename().replace("_", " ")
	var searchable := "%s %s %s %s" % [display_name, rel, folder, ext]
	if ext == "txt":
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.size() > max_indexed_text_bytes:
			bytes = bytes.slice(0, max_indexed_text_bytes)
		searchable += " " + bytes.get_string_from_utf8()
	return {
		"title": display_name,
		"path": path,
		"relative": rel,
		"folder": folder,
		"type": ext,
		"search": searchable.to_lower()
	}

func _filter(_unused = null) -> void:
	shown.clear()
	files.clear()
	var query := search.text.strip_edges().to_lower()
	var wanted_folder := folders.get_item_text(folders.selected)
	var wanted_type := types.get_item_text(types.selected)

	for e in entries:
		var ok_folder: bool = (wanted_folder == "ALL FOLDERS") or (String(e["folder"]) == wanted_folder)
		var ok_type: bool = (wanted_type == "ALL TYPES") or (_type_name(String(e["type"])) == wanted_type)
		var ok_search: bool = query.is_empty() or String(e["search"]).contains(query)
		if ok_folder and ok_type and ok_search:
			shown.append(e)
			files.add_item("%s  [%s]" % [e.relative, String(e.type).to_upper()])

	results.text = "%d result%s" % [shown.size(), "" if shown.size() == 1 else "s"]
	if shown.is_empty():
		_clear("No matching files.")
	else:
		files.select(0)
		_open(shown[0])

func _open_selected(index: int) -> void:
	if index >= 0 and index < shown.size():
		_open(shown[index])

func _open(e: Dictionary) -> void:
	current = e
	title.text = e.title
	status.text = e.relative
	_hide_viewers()
	zoom = 1.0
	_update_zoom()

	match e.type:
		"txt":
			text_view.text = FileAccess.get_file_as_bytes(e.path).get_string_from_utf8()
			text_view.visible = true
		"jpg", "jpeg", "png", "webp":
			_open_image(e.path, e.type)
		"pdf":
			pdf_info.text = "This PDF opens in your computer's default PDF reader.\n\n" + e.relative
			pdf_box.visible = true

func _open_image(path: String, ext: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(path)
	var image := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	match ext:
		"jpg", "jpeg": err = image.load_jpg_from_buffer(bytes)
		"png": err = image.load_png_from_buffer(bytes)
		"webp": err = image.load_webp_from_buffer(bytes)
	if err != OK:
		_clear("Could not decode image.")
		return
	image_view.texture = ImageTexture.create_from_image(image)
	image_scroll.visible = true
	_apply_zoom()

func _open_pdf() -> void:
	if current.is_empty() or current.type != "pdf":
		return
	var bytes := FileAccess.get_file_as_bytes(current.path)
	var cache := "user://archive_pdf_cache"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache))
	var safe_name := String(current.relative).replace("/", "__").replace("\\", "__")
	var destination := cache.path_join(safe_name)
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		status.text = "Could not create temporary PDF."
		return
	file.store_buffer(bytes)
	file.close()
	var absolute := ProjectSettings.globalize_path(destination)
	var err := OS.shell_open(absolute)
	status.text = "Opened PDF." if err == OK else "PDF copied to: " + absolute

func _zoom_in() -> void:
	if image_scroll.visible:
		zoom = minf(5.0, zoom + 0.25)
		_apply_zoom()

func _zoom_out() -> void:
	if image_scroll.visible:
		zoom = maxf(0.25, zoom - 0.25)
		_apply_zoom()

func _reset_zoom() -> void:
	zoom = 1.0
	_apply_zoom()

func _apply_zoom() -> void:
	if image_view.texture:
		image_view.custom_minimum_size = image_view.texture.get_size() * zoom
	_update_zoom()

func _update_zoom() -> void:
	if zoom_label:
		zoom_label.text = "%d%%" % int(zoom * 100.0)

func _hide_viewers() -> void:
	text_view.visible = false
	image_scroll.visible = false
	pdf_box.visible = false
	image_view.texture = null

func _clear(message: String) -> void:
	current = {}
	title.text = "ARCHIVE"
	status.text = message
	_hide_viewers()

func _rebuild_folder_list() -> void:
	var unique: Array[String] = []
	for e in entries:
		if not unique.has(e.folder):
			unique.append(e.folder)
	unique.sort()
	folders.clear()
	folders.add_item("ALL FOLDERS")
	for folder in unique:
		folders.add_item(folder)

func _type_name(ext: String) -> String:
	if ext == "txt": return "TEXT"
	if ext == "pdf": return "PDF"
	return "IMAGES"

func _ensure_action() -> void:
	if InputMap.has_action("archive_toggle"):
		return
	InputMap.add_action("archive_toggle")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F6
	InputMap.action_add_event("archive_toggle", key)

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0.025, 0.025, 0.03, 0.985)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 8)
	margin.add_child(main)

	var top := HBoxContainer.new()
	main.add_child(top)

	var heading := Label.new()
	heading.text = "SEARCHABLE ARCHIVE"
	heading.add_theme_font_size_override("font_size", 24)
	top.add_child(heading)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	var rebuild := Button.new()
	rebuild.text = "REBUILD INDEX"
	rebuild.pressed.connect(rebuild_archive)
	top.add_child(rebuild)

	var close := Button.new()
	close.text = "CLOSE"
	close.pressed.connect(hide)
	top.add_child(close)

	var filter_row := HBoxContainer.new()
	main.add_child(filter_row)

	search = LineEdit.new()
	search.placeholder_text = "Search filenames, folders, paths, and TXT contents..."
	search.clear_button_enabled = true
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(_filter)
	filter_row.add_child(search)

	folders = OptionButton.new()
	folders.custom_minimum_size.x = 190
	folders.add_item("ALL FOLDERS")
	folders.item_selected.connect(_filter)
	filter_row.add_child(folders)

	types = OptionButton.new()
	types.custom_minimum_size.x = 135
	for item in ["ALL TYPES", "TEXT", "PDF", "IMAGES"]:
		types.add_item(item)
	types.item_selected.connect(_filter)
	filter_row.add_child(types)

	results = Label.new()
	results.custom_minimum_size.x = 90
	results.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	filter_row.add_child(results)

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
	title.text = "ARCHIVE"
	title.add_theme_font_size_override("font_size", 22)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(title)

	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(status)

	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(frame)

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.custom_minimum_size = Vector2.ZERO
	frame.add_child(stack)

	text_view = RichTextLabel.new()

	text_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_view.custom_minimum_size = Vector2.ZERO

	text_view.fit_content = false
	text_view.scroll_active = true
	text_view.scroll_following = false
	text_view.selection_enabled = true
	text_view.context_menu_enabled = true

	# Keep every line inside the available reader width.
	text_view.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY

	text_view.add_theme_font_size_override("normal_font_size", 18)

	stack.add_child(text_view)

	image_scroll = ScrollContainer.new()
	image_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(image_scroll)

	image_view = TextureRect.new()
	image_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_scroll.add_child(image_view)

	pdf_box = VBoxContainer.new()
	pdf_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pdf_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(pdf_box)

	pdf_info = Label.new()
	pdf_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pdf_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pdf_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pdf_box.add_child(pdf_info)

	var pdf_button := Button.new()
	pdf_button.text = "OPEN PDF"
	pdf_button.custom_minimum_size = Vector2(220, 52)
	pdf_button.pressed.connect(_open_pdf)
	pdf_box.add_child(pdf_button)

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
	reset.text = "RESET ZOOM"
	reset.pressed.connect(_reset_zoom)
	controls.add_child(reset)

	_hide_viewers()
