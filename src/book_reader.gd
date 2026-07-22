extends Control

@onready var selector: OptionButton = $PanelContainer2/MarginContainer/VBoxContainer/BookSelector
@onready var title_label: Label = $PanelContainer2/MarginContainer/VBoxContainer/Title
@onready var author_label: Label = $PanelContainer2/MarginContainer/VBoxContainer/Author
@onready var text_label: RichTextLabel = $PanelContainer2/MarginContainer/VBoxContainer/Text
@onready var exit_button: Button = $PanelContainer2/MarginContainer/VBoxContainer/Exit


const BOOKS = [
	{
		"title": "The Bible",
		"author": "God",
		"path": "res://assets/books/THE BIBLE by God (final).txt"
	},
	{
		"title": "The Corrupted Chapel",
		"author": "Unknown",
		"path": "res://assets/books/THE CORRUPTED CHAPEL (final).txt"
	},
	{
		"title": "The Dark Forest",
		"author": "Unknown",
		"path": "res://assets/books/THE DARK FOREST.txt"
	},
	{
		"title": "The Dark Castle",
		"author": "Unknown",
		"path": "res://assets/books/THE DARK CASTLE (final).txt"
	},
	{
		"title": "The Shadow in the Painting",
		"author": "Unknown",
		"path": "res://assets/books/THE SHADOW IN THE PAINTING final.txt"
	},
	{
		"title": "The Shadow",
		"author": "Unknown",
		"path": "res://assets/books/THE SHADOW-compressed.txt"
	},
	{
		"title": "The Cult of Dagon's Embrace",
		"author": "Unknown",
		"path": "res://assets/books/THE CULT OF DAGONS EMBRACE-compressed.txt"
	},
	{
		"title": "Invaders From Above",
		"author": "Unknown",
		"path": "res://assets/books/INVADERS FROM ABOVE-compressed.txt"
	}
]


func _ready() -> void:
	print("BOOK READER READY")

	exit_button.pressed.connect(close_book)
	selector.item_selected.connect(_on_book_selected)

	selector.clear()

	for book in BOOKS:
		selector.add_item(book["title"])

	if BOOKS.size() > 0:
		load_book(0)

	hide()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_B:
				if visible:
					close_book()
				else:
					show()
					move_to_front()

				get_viewport().set_input_as_handled()

			elif event.keycode == KEY_ESCAPE and visible:
				close_book()
				get_viewport().set_input_as_handled()


func _on_book_selected(index: int) -> void:
	load_book(index)


func load_book(index: int) -> void:
	if index < 0 or index >= BOOKS.size():
		return

	var book: Dictionary = BOOKS[index]
	var file_path: String = book["path"]

	title_label.text = book["title"]
	author_label.text = book["author"]

	if not FileAccess.file_exists(file_path):
		text_label.text = "BOOK FILE NOT FOUND:\n\n" + file_path
		push_error("BOOK FILE NOT FOUND: " + file_path)
		return

	text_label.text = FileAccess.get_file_as_string(file_path)
	text_label.scroll_to_line(0)


func open_book(
	file_path: String,
	book_title: String = "Unknown Book",
	book_author: String = "Unknown Author"
) -> void:
	if not FileAccess.file_exists(file_path):
		push_error("BOOK FILE NOT FOUND: " + file_path)
		return

	title_label.text = book_title
	author_label.text = book_author
	text_label.text = FileAccess.get_file_as_string(file_path)
	text_label.scroll_to_line(0)

	show()
	move_to_front()


func close_book() -> void:
	hide()
