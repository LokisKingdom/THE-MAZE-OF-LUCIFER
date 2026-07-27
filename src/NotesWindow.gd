extends Control

@onready var note_selector: OptionButton = $Panel/VBoxContainer/NoteSelector
@onready var note_title: Label = $Panel/VBoxContainer/NoteTitle
@onready var note_text: RichTextLabel = $Panel/VBoxContainer/NoteText
@onready var exit_button: Button = $Panel/VBoxContainer/ExitButton


func _ready() -> void:
	exit_button.pressed.connect(close_notes)
	note_selector.item_selected.connect(_on_note_selected)

	hide()
	refresh_note_list()


func open_notes() -> void:
	refresh_note_list()
	show()


func close_notes() -> void:
	hide()


func refresh_note_list() -> void:
	note_selector.clear()
	note_title.text = ""
	note_text.text = ""

	if NoteLibrary.unlocked_notes.is_empty():
		note_selector.disabled = true
		note_title.text = "NO NOTES DISCOVERED"
		note_text.text = "Documents found throughout the world will appear here."
		return

	note_selector.disabled = false

	for note in NoteLibrary.unlocked_notes:
		note_selector.add_item(note["title"])

	load_note(0)


func _on_note_selected(index: int) -> void:
	load_note(index)


func load_note(index: int) -> void:
	if index < 0 or index >= NoteLibrary.unlocked_notes.size():
		return

	var note: Dictionary = NoteLibrary.unlocked_notes[index]

	note_title.text = note["title"]
	note_text.text = NoteLibrary.read_note(note)
