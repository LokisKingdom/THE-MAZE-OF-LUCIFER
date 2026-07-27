extends Area2D
class_name NotePickup


@export var pickup_message_seconds: float = 4.0

var collected: bool = false


# ------------------------------------------------------------
# FUNCTION: _ready()
# ------------------------------------------------------------

func _ready() -> void:
	body_entered.connect(_on_body_entered)


# ------------------------------------------------------------
# FUNCTION: _on_body_entered()
#
# Unlocks one random undiscovered text document.
# ------------------------------------------------------------

func _on_body_entered(body: Node) -> void:
	if collected:
		return

	if not body.is_in_group("player"):
		return

	collected = true

	var unlocked_note: Dictionary = NoteLibrary.unlock_random_note()

	if unlocked_note.is_empty():
		_show_pickup_message(
			"Every surviving document has already been recovered."
		)
	else:
		_show_pickup_message(
			"NOTE DISCOVERED\n%s" % str(unlocked_note["title"])
		)

	# Allow the archive to refresh immediately if it is currently open.
	var archive := get_tree().get_first_node_in_group("searchable_archive")

	if archive != null and archive.has_method("rebuild_archive"):
		archive.rebuild_archive()

	queue_free()


# ------------------------------------------------------------
# FUNCTION: _show_pickup_message()
#
# Attempts several common HUD methods.
# Falls back to printing the message.
# ------------------------------------------------------------

func _show_pickup_message(message: String) -> void:
	print(message)

	var hud := get_tree().get_first_node_in_group("hud")

	if hud == null:
		return

	if hud.has_method("show_message"):
		hud.show_message(message, pickup_message_seconds)

	elif hud.has_method("display_message"):
		hud.display_message(message, pickup_message_seconds)

	elif hud.has_method("show_notification"):
		hud.show_notification(message)
