extends Control


@onready var album_selector: OptionButton = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/AlbumSelector


func _ready() -> void:
	populate_album_selector()


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func populate_album_selector() -> void:
	if album_selector == null:
		push_error("AlbumSelector node could not be found.")
		return

	album_selector.clear()

	var albums: Array = MusicManager.library.keys()
	albums.sort()

	for album in albums:
		album_selector.add_item(str(album))

	if not album_selector.item_selected.is_connected(_on_album_selected):
		album_selector.item_selected.connect(_on_album_selected)

	select_current_album_in_dropdown()


func select_current_album_in_dropdown() -> void:
	if MusicManager.current_album_name.is_empty():
		return

	for index in range(album_selector.item_count):
		if album_selector.get_item_text(index) == MusicManager.current_album_name:
			album_selector.select(index)
			return


func _on_album_selected(index: int) -> void:
	if index < 0 or index >= album_selector.item_count:
		return

	var album_name := album_selector.get_item_text(index)
	MusicManager.select_album(album_name)
