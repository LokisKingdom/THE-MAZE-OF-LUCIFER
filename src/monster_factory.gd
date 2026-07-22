class_name MonsterFactory
extends RefCounted


const CSV_PATH = &"res://assets/data/monsters.csv"

static var monster_data: Dictionary = {}
static var _column_indices: Dictionary = {}


static func _static_init() -> void:
	_load_monster_data()


static func _load_monster_data() -> void:
	# Clear existing cached data in case this function is called again.
	monster_data.clear()
	_column_indices.clear()

	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if not file:
		printerr("Failed to open CSV file at ", CSV_PATH)
		return

	# Parse the header row and record the index of every column.
	var headers := file.get_csv_line()

	for i in headers.size():
		var header_name := String(headers[i]).strip_edges()
		_column_indices[StringName(header_name)] = i

	# Read monster data.
	while not file.eof_reached():
		var row := file.get_csv_line()

		if row.is_empty():
			continue

		if row[0].strip_edges().is_empty():
			continue

		var appearances: Array = []
		var appearance_value := _get_required_value(row, &"appearance")

		if not appearance_value.is_empty():
			appearances = appearance_value.split(",")

		var slug := StringName(_get_required_value(row, &"slug"))

		monster_data[slug] = {
			&"name": _get_required_value(row, &"name"),
			&"species": _get_required_value(row, &"species"),
			&"faction": _get_required_value(row, &"faction"),

			# Allegiance is optional so existing CSV files still work.
			&"allegiance": _get_optional_value(row, &"allegiance"),

			&"appearance": appearances,
			&"speed": _get_required_value(row, &"speed"),
			&"strength": _get_required_value(row, &"strength").to_int(),
			&"max_hp": _get_required_value(row, &"max_hp").to_int(),
			&"behavior": _get_required_value(row, &"behavior"),
			&"sight_radius": _get_required_value(row, &"sight_radius").to_int(),
			&"hit_particles_color":
			Color.from_string(
				_get_required_value(row, &"hit_particles_color"),
				Color(1.0, 0.1, 0.1)
			),
			&"intelligence": _get_required_value(row, &"intelligence").to_int(),
			&"has_head": _get_required_value(row, &"has_head").to_lower() == "true",
			&"has_torso": _get_required_value(row, &"has_torso").to_lower() == "true",
			&"has_legs": _get_required_value(row, &"has_legs").to_lower() == "true",
			&"has_hands": _get_required_value(row, &"has_hands").to_lower() == "true",
		}


static func _get_col(name: StringName) -> int:
	assert(
		_column_indices.has(name),
		"Missing column in monsters.csv: %s" % name
	)

	return int(_column_indices[name])


## Returns a required CSV value.
## Produces an assertion if the column is missing or the row is too short.
static func _get_required_value(
	row: PackedStringArray,
	name: StringName
) -> String:
	var index := _get_col(name)

	assert(
		index >= 0 and index < row.size(),
		"Missing value for required column '%s' in monsters.csv" % name
	)

	return String(row[index]).strip_edges()


## Returns an optional CSV value.
## Returns an empty string if the column or value does not exist.
static func _get_optional_value(
	row: PackedStringArray,
	name: StringName
) -> String:
	if not _column_indices.has(name):
		return ""

	var index := int(_column_indices[name])

	if index < 0 or index >= row.size():
		return ""

	return String(row[index]).strip_edges()


## Creates a monster from a monster slug.
##
## @param slug The slug of the monster to create.
## @param role The role of the monster if it is the player.
## @return The created monster.
static func create_monster(
	slug: StringName,
	role: Roles.Type = Roles.Type.NONE
) -> Monster:
	if monster_data.is_empty():
		_load_monster_data()

	var data := monster_data.get(slug, {}) as Dictionary

	assert(
		not data.is_empty(),
		"Monster not found: %s" % slug
	)

	var monster := Monster.new(true)

	monster.species = Species.Type.get(
		(data.species as String).to_upper(),
		Species.Type.RODENT
	)

	monster.faction = Factions.Type.get(
		(data.faction as String).to_upper(),
		Factions.Type.NONE
	)

	monster.allegiance = Factions.Allegiance.get(
		(data.allegiance as String).to_upper(),
		Factions.Allegiance.NONE
	)

	# Prevent an invalid species from belonging to a restricted allegiance.
	monster.allegiance = Factions.normalize_allegiance(
		monster.faction,
		monster.allegiance
	)

	monster.behavior = _convert_behavior(data.behavior as String)
	monster.hp = data.max_hp
	monster.max_hp = data.max_hp
	monster._base_strength = data.strength
	monster._base_speed = _convert_speed(data.speed as String)
	monster.sight_radius = data.sight_radius
	monster.hit_particles_color = data.hit_particles_color
	monster.intelligence = data.intelligence
	monster.slug = slug
	monster.name = data.name
	monster.role = role
	monster.has_head = data.has_head
	monster.has_torso = data.has_torso
	monster.has_legs = data.has_legs
	monster.has_hands = data.has_hands

	if (
		data.appearance is Array
		and not (data.appearance as Array).is_empty()
	):
		var appearances := data.appearance as Array

		if not appearances.is_empty():
			monster.variant = randi() % appearances.size()

	# If a role is specified, validate the species and apply role data.
	if role != Roles.Type.NONE:
		var allowed_species := Roles.get_allowed_species(role)

		assert(
			monster.species in allowed_species,
			(
				"Species %s not allowed for role %s"
				% [
					Species.Type.keys()[monster.species],
					Roles.Type.keys()[role]
				]
			)
		)

		# Set the original faction/type from the role.
		monster.faction = Roles.get_faction(role)

		# Player roles currently begin without a special allegiance.
		monster.allegiance = Factions.Allegiance.NONE

		# Set starting skills from the role.
		var starting_skills := Roles.get_starting_skills(role)

		for skill_type: Skills.Type in starting_skills:
			monster.skill_levels[skill_type] = (
				starting_skills[skill_type] as Skills.Level
			)

	# If role is NONE, equip the monster's starting items.
	if role == Roles.Type.NONE:
		_equip_starting_monster(monster)

	# Initialize the behavior tree after all properties are set.
	monster.behavior_tree = MonsterAI.create_behavior_tree(monster)

	return monster


static func _convert_speed(speed_value: String) -> int:
	match speed_value.to_upper():
		&"VERY_SLOW":
			return Monster.SPEED_VERY_SLOW

		&"SLOW":
			return Monster.SPEED_SLOW

		&"NORMAL":
			return Monster.SPEED_NORMAL

		&"FAST":
			return Monster.SPEED_FAST

		&"VERY_FAST":
			return Monster.SPEED_VERY_FAST

		"":
			return Monster.SPEED_NORMAL

		_:
			assert(
				false,
				"Invalid speed value in CSV: %s" % speed_value
			)

			return Monster.SPEED_NORMAL


static func _convert_behavior(
	behavior_value: String
) -> Monster.Behavior:
	if behavior_value.is_empty():
		return Monster.Behavior.PASSIVE

	return Monster.Behavior.get(
		behavior_value.to_upper(),
		Monster.Behavior.PASSIVE
	)

static func _equip_starting_monster(monster: Monster) -> void:
	var add := func(
		item_name: StringName,
		quantity: int = 1,
		slot: Variant = null
	) -> void:
		if quantity < 1:
			return

		var item := ItemFactory.create_item(item_name)
		item.quantity = quantity
		monster.add_item(item)

		if slot is Equipment.Slot:
			monster.equipment.equip(
				item,
				slot as Equipment.Slot
			)

	# Temporary combat-test weapons.
	# The AI should detect these in inventory and equip them.
	match monster.slug:
		&"knight":
			add.call(&"longsword")

		&"monk":
			add.call(&"dagger")

		&"valkyrie":
			add.call(&"longsword")

		&"skeleton":
			add.call(&"longsword")

		&"zombie":
			add.call(&"dagger")

		&"satan":
			add.call(&"longsword")

	# Existing loot system.
	match monster.species:
		Species.Type.UNDEAD:
			add.call(
				&"gold",
				Dice.roll(1, 50) if Dice.chance(0.5) else 0
			)

		Species.Type.HUMAN:
			add.call(
				&"apple",
				Dice.roll(1, 2) if Dice.chance(0.3) else 0
			)

			add.call(
				&"orange",
				Dice.roll(1, 2) if Dice.chance(0.3) else 0
			)

			add.call(
				&"banana",
				Dice.roll(1, 2) if Dice.chance(0.3) else 0
			)
