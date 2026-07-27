class_name PlayerPickupAction
extends PickupAction


func _init(p_selections: Array[ItemSelection] = []) -> void:
	super(World.player, p_selections)


func _execute(map: Map, result: ActionResult) -> bool:
	var success := super(map, result)

	if not success:
		return false

	# Archive-note messages are already formatted correctly.
	if result.message.begins_with("NOTE DISCOVERED"):
		return true

	if result.message.begins_with("Every surviving document"):
		return true

	# Only rewrite ordinary pickup messages when the expected phrase exists.
	if "picked up" in result.message:
		var message_parts := result.message.split(
			"picked up",
			false,
			1
		)

		if message_parts.size() >= 2:
			var item_text := message_parts[1].strip_edges()

			if "x" in result.message:
				result.message = item_text
			else:
				result.message = "Picked up %s" % item_text

	return true

func _to_string() -> String:
	return "PlayerPickupAction(%s)" % [selections]
