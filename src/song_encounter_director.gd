class_name SongEncounterDirector
extends RefCounted


# A-F: no encounter.
# G-Z: danger levels 1-20.
const FIRST_DANGER_LETTER := 71 # Unicode/ASCII value for G.
const LAST_DANGER_LETTER := 90 # Unicode/ASCII value for Z.
const MAX_DANGER_LEVEL := 20

# Keep special/player definitions out of random enemy encounters.
const EXCLUDED_MONSTERS: Array[StringName] = [
	&"human",
]

# Prevent additional enemies from appearing directly beside the player.
const MINIMUM_PLAYER_DISTANCE := 5

# Number of placement attempts allowed for each enemy.
const PLACEMENT_ATTEMPTS_PER_MONSTER := 50

# Existing Statico item IDs can be added or changed here.
# These are only examples; invalid item IDs are ignored.
const LOW_REWARD_ITEMS: Array[StringName] = [
	&"food_ration",
	&"healing_potion",
]

const MID_REWARD_ITEMS: Array[StringName] = [
	&"healing_potion",
	&"orange_scroll",
	&"green_scroll",
]

const HIGH_REWARD_ITEMS: Array[StringName] = [
	&"healing_potion",
	&"orange_scroll",
	&"green_scroll",
]

# Used to make sure a generated level receives its song encounter only once.
static var processed_map_ids: Dictionary = {}

static var _rng := RandomNumberGenerator.new()


## Apply the additional song-based population after normal map generation.
##
## song_title:
## The displayed filename or title of the song currently playing.
##
## Returns a summary dictionary for debugging/UI:
## {
##     "letter": "M",
##     "danger": 7,
##     "monsters_spawned": 7,
##     "items_spawned": 2
## }
static func populate_from_song(
	map: Map,
	player: Monster,
	song_title: String
) -> Dictionary:
	var result := {
		"letter": "",
		"danger": 0,
		"monsters_spawned": 0,
		"items_spawned": 0,
	}

	if map == null:
		Log.w("Song encounter skipped: map was null")
		return result

	# A generated map should only receive this bonus population once.
	var map_key := _get_map_key(map)

	if processed_map_ids.has(map_key):
		Log.d("Song encounter already created for map: %s" % map_key)
		return result

	processed_map_ids[map_key] = true

	var first_letter := get_first_alphabetical_letter(song_title)
	var danger_level := letter_to_danger(first_letter)

	result.letter = first_letter
	result.danger = danger_level

	if danger_level <= 0:
		Log.i(
			(
				"Song encounter: '%s' begins with '%s'; "
				+ "no additional enemies."
			)
			% [song_title, first_letter]
		)
		return result

	_rng.randomize()

	# A Z song summons one Satan instead of twenty enemies.
	var monster_count := (
		1
		if danger_level == MAX_DANGER_LEVEL
		else danger_level
	)

	# Rewards rise more slowly than monster count.
	var reward_count := get_reward_count(danger_level)

	var monsters_spawned := _spawn_monsters(
		map,
		player,
		danger_level,
		monster_count
	)

	var items_spawned := _spawn_reward_items(
		map,
		player,
		danger_level,
		reward_count
	)

	result.monsters_spawned = monsters_spawned
	result.items_spawned = items_spawned

	Log.i(
		(
			"Song encounter: '%s' | Letter %s | Danger %d | "
			+ "Enemies %d/%d | Rewards %d/%d"
		)
		% [
			song_title,
			first_letter,
			danger_level,
			monsters_spawned,
			monster_count,
			items_spawned,
			reward_count,
		]
	)

	return result


## Return the first actual A-Z letter in the song title.
##
## This deliberately skips quotation marks, brackets, numbers, spaces,
## punctuation, and filename decorations.
##
## Examples:
## "01 - ZOMBIE.mp3" -> Z
## "(Live) GOLGOTHA.wav" -> L
## "_A WARM PLACE.mp3" -> A
static func get_first_alphabetical_letter(song_title: String) -> String:
	var cleaned_title := song_title.strip_edges().to_upper()

	for index in range(cleaned_title.length()):
		var character := cleaned_title.substr(index, 1)
		var code := character.unicode_at(0)

		# Ignore spaces, punctuation, brackets, and leading numbers.
		if (
			character == " "
			or character == "-"
			or character == "_"
			or character == "."
			or character == "("
			or character == ")"
			or character == "["
			or character == "]"
			or character == "\""
			or character == "'"
			or (code >= 48 and code <= 57)
		):
			continue

		# English A-Z keeps the ordinary difficulty scale.
		if code >= 65 and code <= 90:
			return character

		# Any other writing system begins at maximum danger.
		return "Z"

	return ""


## Convert:
## A-F -> 0
## G   -> 1
## H   -> 2
## ...
## Z   -> 20
static func letter_to_danger(letter: String) -> int:
	if letter.is_empty():
		return 0

	var normalized := letter.to_upper()
	var code := normalized.unicode_at(0)

	if code < FIRST_DANGER_LETTER:
		return 0

	if code > LAST_DANGER_LETTER:
		return 0

	return code - FIRST_DANGER_LETTER + 1


## Reward quantity rises with danger, but not at one item per enemy.
##
## G-K: one additional item.
## L-P: two.
## Q-U: three.
## V-Z: four.
static func get_reward_count(danger_level: int) -> int:
	if danger_level <= 0:
		return 0

	return clampi(1 + int((danger_level - 1) / 5.0), 1, 4)


static func _spawn_monsters(
	map: Map,
	player: Monster,
	danger_level: int,
	count: int
) -> int:
	var eligible_monsters := _get_monsters_for_danger(danger_level)

	if eligible_monsters.is_empty():
		Log.w(
			"No eligible monsters found for danger level %d"
			% danger_level
		)
		return 0

	var spawned := 0

	for _index in range(count):
		var monster_id: StringName = eligible_monsters[
			_rng.randi_range(0, eligible_monsters.size() - 1)
		]

		var position := _find_spawn_position(map, player)

		if position == Vector2i(-1, -1):
			Log.w("Could not find a valid song-monster spawn position")
			continue

		var monster := MonsterFactory.create_monster(monster_id)
		map.cells[position.x][position.y].monster = monster
		spawned += 1

	return spawned


## Dynamically ranks every available monster by its current CSV statistics.
##
## G uses monsters from the weakest part of the list.
## Z uses monsters from the strongest part.
##
## Each danger level has some overlap with the levels beside it so encounters
## are varied instead of containing one exact species every time.
static func _get_monsters_for_danger(
	danger_level: int
) -> Array[StringName]:

	# TEMPORARY POLICE TEST:
	# Every G-Y song encounter will spawn only police.
	if danger_level > 0 and danger_level < MAX_DANGER_LEVEL:
		return [&"police"]

	# Z songs summon Satan exclusively.
	if danger_level == MAX_DANGER_LEVEL:
		if MonsterFactory.monster_data.is_empty():
			MonsterFactory._static_init()

		if MonsterFactory.monster_data.has(&"satan"):
			return [&"satan"]

		Log.e(
			"Z encounter requested, but satan is missing from monsters.csv"
		)
		return []
		
	if MonsterFactory.monster_data.is_empty():
		MonsterFactory._static_init()

	var ranked: Array[Dictionary] = []

	for monster_id: StringName in MonsterFactory.monster_data:
		if monster_id in EXCLUDED_MONSTERS:
			continue

		var data: Dictionary = MonsterFactory.monster_data[monster_id]
		var score := _calculate_monster_danger(data)

		ranked.append({
			"id": monster_id,
			"score": score,
		})

	ranked.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.score) < float(b.score)
	)

	if ranked.is_empty():
		return []

	# Convert danger 1-20 into a location from 0.0-1.0.
	var normalized_danger := float(danger_level - 1) / float(
		MAX_DANGER_LEVEL - 1
	)

	var center_index := int(
		round(normalized_danger * float(ranked.size() - 1))
	)

	# Include nearby ranks to provide variety.
	# With a small monster list, this still returns useful choices.
	var window_size := maxi(1, int(ceil(ranked.size() * 0.20)))
	var start_index := maxi(0, center_index - window_size)
	var end_index := mini(
		ranked.size() - 1,
		center_index + window_size
	)

	var result: Array[StringName] = []

	for index in range(start_index, end_index + 1):
		result.append(ranked[index].id as StringName)

	return result


## Estimated difficulty from Statico's existing CSV properties.
##
## HP and strength matter most.
## Speed, intelligence, and sight provide smaller modifiers.
static func _calculate_monster_danger(data: Dictionary) -> float:
	var max_hp := float(data.get(&"max_hp", 1))
	var strength := float(data.get(&"strength", 1))
	var intelligence := float(data.get(&"intelligence", 1))
	var sight_radius := float(data.get(&"sight_radius", 1))
	var speed_score := _speed_to_score(
		str(data.get(&"speed", "normal"))
	)

	return (
		max_hp * 1.5
		+ strength * 2.5
		+ intelligence * 0.5
		+ sight_radius * 0.25
		+ speed_score
	)


static func _speed_to_score(speed_name: String) -> float:
	match speed_name.strip_edges().to_lower():
		"very_slow", "very slow":
			return -3.0
		"slow":
			return -1.5
		"fast":
			return 2.0
		"very_fast", "very fast":
			return 4.0
		_:
			return 0.0


static func _spawn_reward_items(
	map: Map,
	player: Monster,
	danger_level: int,
	count: int
) -> int:
	if ItemFactory.item_data.is_empty():
		ItemFactory._static_init()

	var candidates := _get_reward_candidates(danger_level)

	if candidates.is_empty():
		Log.w("No valid song reward items were found")
		return 0

	var spawned := 0

	for _index in range(count):
		var position := _find_reward_position(map, player)

		if position == Vector2i(-1, -1):
			continue

		var item_id: StringName = candidates[
			_rng.randi_range(0, candidates.size() - 1)
		]

		var item := ItemFactory.create_item(item_id)
		map.add_item_with_stacking(position, item)
		spawned += 1

	return spawned


static func _get_reward_candidates(
	danger_level: int
) -> Array[StringName]:
	var requested_items: Array[StringName]

	if danger_level <= 6:
		requested_items = LOW_REWARD_ITEMS
	elif danger_level <= 13:
		requested_items = MID_REWARD_ITEMS
	else:
		requested_items = HIGH_REWARD_ITEMS

	var valid_items: Array[StringName] = []

	for item_id: StringName in requested_items:
		if ItemFactory.item_data.has(item_id):
			valid_items.append(item_id)

	# Fallback: use any normally spawnable item if the example IDs above
	# do not match the user's current items.csv.
	if valid_items.is_empty():
		for item_id: StringName in ItemFactory.item_data:
			var item_data: Dictionary = ItemFactory.item_data[item_id]
			var probability := int(item_data.get(&"probability", 0))

			if probability > 0:
				valid_items.append(item_id)

	return valid_items


static func _find_spawn_position(
	map: Map,
	player: Monster
) -> Vector2i:
	var player_position := map.find_monster_position(player)

	for _attempt in range(PLACEMENT_ATTEMPTS_PER_MONSTER):
		var position := Vector2i(
			_rng.randi_range(1, map.width - 2),
			_rng.randi_range(1, map.height - 2)
		)

		if position.distance_to(player_position) < MINIMUM_PLAYER_DISTANCE:
			continue

		var cell: MapCell = map.cells[position.x][position.y]

		if _is_valid_monster_cell(cell):
			return position

	return Vector2i(-1, -1)


static func _find_reward_position(
	map: Map,
	player: Monster
) -> Vector2i:
	var player_position := map.find_monster_position(player)

	for _attempt in range(PLACEMENT_ATTEMPTS_PER_MONSTER):
		var position := Vector2i(
			_rng.randi_range(1, map.width - 2),
			_rng.randi_range(1, map.height - 2)
		)

		if position.distance_to(player_position) < 3:
			continue

		var cell: MapCell = map.cells[position.x][position.y]

		if _is_valid_reward_cell(cell):
			return position

	return Vector2i(-1, -1)


static func _is_valid_monster_cell(cell: MapCell) -> bool:
	return (
		cell.terrain.type == Terrain.Type.DUNGEON_FLOOR
		and cell.monster == null
		and cell.obstacle == null
	)


static func _is_valid_reward_cell(cell: MapCell) -> bool:
	return (
		cell.terrain.type == Terrain.Type.DUNGEON_FLOOR
		and cell.monster == null
		and cell.obstacle == null
	)


static func _get_map_key(map: Map) -> String:
	if not str(map.id).is_empty():
		return str(map.id)

	# Fallback for maps whose ID has not yet been assigned.
	return "depth_%d_instance_%d" % [
		map.depth,
		map.get_instance_id(),
	]


## Useful when restarting the game without restarting the Godot application.
static func reset() -> void:
	processed_map_ids.clear()
