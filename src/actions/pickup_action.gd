class_name PickupAction
extends ActorAction

var selections: Array[ItemSelection]


func _init(p_actor: Monster, p_selections: Array[ItemSelection] = []) -> void:
	super(p_actor)
	selections = p_selections


func _execute(map: Map, result: ActionResult) -> bool:
	if not super(map, result):
		return false

	Log.d("[DragDrop] Executing PickupAction")

	var current_pos := map.find_monster_position(actor)

	if not current_pos:
		return false

	if selections.is_empty():
		var item := map.get_top_item(current_pos)

		if not item:
			Log.d(
				"[DragDrop] No items to pick up at position: %s"
				% current_pos
			)

			result.message = "Nothing to pick up here."
			return false

		Log.d(
			"[DragDrop] Auto-selecting top item: %s"
			% item.get_name(Item.NameFormat.THE)
		)

		selections = [ItemSelection.new(item)]

	var success := false
	var picked_up_items: Array[Item] = []
	var discovered_notes: Array[String] = []

	for selection in selections:
		var item: Item = selection.item
		var quantity: int = selection.quantity

		Log.d(
			(
				"[DragDrop] Processing pickup selection: %s "
				+ "(quantity: %d)"
			)
			% [
				item.get_name(Item.NameFormat.THE),
				quantity,
			]
		)

		if not map.get_items(current_pos).has(item):
			Log.d(
				"[DragDrop] Item not found at location: %s"
				% item.get_name(Item.NameFormat.THE)
			)
			continue

		var actual_quantity := mini(quantity, item.quantity)

		if actual_quantity <= 0:
			Log.d(
				"[DragDrop] Invalid quantity: %d"
				% actual_quantity
			)
			continue

		# --------------------------------------------------------
		# SPECIAL COLLECTIBLE: LOST NOTE
		#
		# The note is removed from the map and unlocks one random
		# archive document instead of entering the inventory.
		# --------------------------------------------------------

		if _is_lost_note(item):
			map.remove_item(current_pos, item)

			var unlocked_note: Dictionary = (
				NoteLibrary.unlock_random_note()
			)

			if unlocked_note.is_empty():
				discovered_notes.append(
					"Every surviving document has already been recovered."
				)
			else:
				var note_title := str(
					unlocked_note.get("title", "Unknown Document")
				)

				discovered_notes.append(note_title)

				Log.i(
					"Archive note discovered: %s"
					% note_title
				)

			result.add_effect(
				PickupEffect.new(actor, item, current_pos)
			)

			success = true
			continue

		# --------------------------------------------------------
		# NORMAL ITEM PICKUP
		# --------------------------------------------------------

		var new_item: Item

		if actual_quantity == item.quantity:
			Log.d(
				(
					"[DragDrop] Taking whole stack: %s "
					+ "(quantity: %d)"
				)
				% [
					item.get_name(Item.NameFormat.THE),
					item.quantity,
				]
			)

			new_item = item
			map.remove_item(current_pos, item)

		else:
			Log.d(
				(
					"[DragDrop] Taking partial stack: %s "
					+ "(taking %d of %d)"
				)
				% [
					item.get_name(Item.NameFormat.THE),
					actual_quantity,
					item.quantity,
				]
			)

			new_item = item.split(actual_quantity)

			if not new_item:
				Log.d("[DragDrop] Failed to split item")
				continue

		Log.d(
			"[DragDrop] Adding item to inventory: %s"
			% new_item.get_name(Item.NameFormat.THE)
		)

		actor.add_item(new_item)
		picked_up_items.append(new_item)
		success = true

		result.add_effect(
			PickupEffect.new(actor, new_item, current_pos)
		)

	if success:
		if not discovered_notes.is_empty():
			if discovered_notes.size() == 1:
				result.message = (
					"NOTE DISCOVERED: %s"
					% discovered_notes[0]
				)
			else:
				result.message = (
					"%d notes were added to the archive."
					% discovered_notes.size()
				)

		elif picked_up_items.size() == 1:
			var picked_item: Item = picked_up_items[0]

			result.message = (
				"%s picked up %s."
				% [
					actor,
					picked_item.get_name(Item.NameFormat.AN),
				]
			)

		else:
			result.message = (
				"%s picked up multiple items."
				% actor
			)

	return success

func _is_lost_note(item: Item) -> bool:
	var item_name := item.get_name(
		Item.NameFormat.PLAIN
	).strip_edges().to_lower()

	return item_name == "lost note"

func _to_string() -> String:
	return "PickupAction(actor: %s)" % actor
