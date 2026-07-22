class_name Factions
extends RefCounted


## Biological or supernatural type.
## Kept as "Type" so existing project references are less likely to break.
enum Type {
	NONE,
	CRITTERS,
	MONSTERS,
	HUMAN,
	UNDEAD,
	ORC,
	DEMON,
}


## Political, religious, or social allegiance.
##
## Allegiance can override normal species hostility.
## For example, humans, orcs, demons, and undead belonging to the
## Cult of the Moon will recognize each other as allies.
enum Allegiance {
	NONE,

	# Human-only factions
	HUMAN_SURVIVORS,
	TOWN_GUARD,
	MERCENARIES,

	# Mixed-species religious factions
	CULT_OF_THE_MOON,
}


# -------------------------------------------------------------------------
# SPECIES INFORMATION
# -------------------------------------------------------------------------

## Returns a display name for a species/type.
static func get_species_name(species: Type) -> String:
	match species:
		Type.NONE:
			return "None"
		Type.CRITTERS:
			return "Critters"
		Type.MONSTERS:
			return "Monsters"
		Type.HUMAN:
			return "Humans"
		Type.UNDEAD:
			return "Undead"
		Type.ORC:
			return "Orcs"
		Type.DEMON:
			return "Demons"
		_:
			return "Unknown Species"


## Compatibility method for existing code that uses Factions.get_name().
static func get_name(species: Type) -> String:
	return get_species_name(species)


## Returns a description for a species/type.
static func get_species_description(species: Type) -> String:
	match species:
		Type.NONE:
			return "No species classification."
		Type.CRITTERS:
			return "Creatures that wander the caves, wilderness, and ruins, usually looking for food."
		Type.MONSTERS:
			return "Dangerous creatures that commonly prey upon humans and other living things."
		Type.HUMAN:
			return "Humans are capable of reason, language, religion, politics, and organized society."
		Type.UNDEAD:
			return "Creatures that have died but continue to move through supernatural means."
		Type.ORC:
			return "A people often treated as enemies by human society, though individuals may belong to many different factions."
		Type.DEMON:
			return "Supernatural beings originating from infernal or otherworldly realms."
		_:
			return "Unknown species."


## Compatibility method for existing code that uses
## Factions.get_description().
static func get_description(species: Type) -> String:
	return get_species_description(species)


# -------------------------------------------------------------------------
# ALLEGIANCE INFORMATION
# -------------------------------------------------------------------------

## Returns a display name for an allegiance.
static func get_allegiance_name(allegiance: Allegiance) -> String:
	match allegiance:
		Allegiance.NONE:
			return "Unaffiliated"
		Allegiance.HUMAN_SURVIVORS:
			return "Human Survivors"
		Allegiance.TOWN_GUARD:
			return "Town Guard"
		Allegiance.MERCENARIES:
			return "Mercenaries"
		Allegiance.CULT_OF_THE_MOON:
			return "Cult of the Moon"
		_:
			return "Unknown Allegiance"


## Returns a description for an allegiance.
static func get_allegiance_description(allegiance: Allegiance) -> String:
	match allegiance:
		Allegiance.NONE:
			return "This creature has no faction allegiance."
		Allegiance.HUMAN_SURVIVORS:
			return "Human survivors who cooperate for protection, food, shelter, and continued survival."
		Allegiance.TOWN_GUARD:
			return "An organized human force responsible for protecting settlements and enforcing local authority."
		Allegiance.MERCENARIES:
			return "Human fighters who accept contracts, guard assignments, and dangerous missions in exchange for payment."
		Allegiance.CULT_OF_THE_MOON:
			return "A secretive religion whose human and non-human members serve the Moon God above the interests of their species."
		_:
			return "Unknown allegiance."


## Returns true when an allegiance only accepts humans.
static func is_human_only(allegiance: Allegiance) -> bool:
	match allegiance:
		Allegiance.HUMAN_SURVIVORS:
			return true
		Allegiance.TOWN_GUARD:
			return true
		Allegiance.MERCENARIES:
			return true
		_:
			return false


## Returns whether a species is permitted to belong to an allegiance.
static func can_join(
	species: Type,
	allegiance: Allegiance
) -> bool:
	if allegiance == Allegiance.NONE:
		return true

	if is_human_only(allegiance):
		return species == Type.HUMAN

	# Mixed-species factions accept any recognized species.
	return species != Type.NONE


## Removes an invalid allegiance.
##
## For example, an orc accidentally assigned to TOWN_GUARD will be treated
## as unaffiliated rather than as a legitimate member of the Town Guard.
static func normalize_allegiance(
	species: Type,
	allegiance: Allegiance
) -> Allegiance:
	if can_join(species, allegiance):
		return allegiance

	return Allegiance.NONE


# -------------------------------------------------------------------------
# RELATIONSHIPS
# -------------------------------------------------------------------------

## Returns true if two species are naturally hostile before allegiance
## is considered.
##
## This preserves the original rule:
## humans are naturally hostile toward non-humans, and non-humans are
## naturally hostile toward humans.
static func are_species_hostile(
	species1: Type,
	species2: Type
) -> bool:
	if species1 == Type.NONE or species2 == Type.NONE:
		return false

	if species1 == Type.HUMAN and species2 != Type.HUMAN:
		return true

	if species1 != Type.HUMAN and species2 == Type.HUMAN:
		return true

	return false


## Returns true if two actors should naturally be hostile.
##
## Existing code can still call:
##
## Factions.are_hostile(species1, species2)
##
## Faction-aware code can call:
##
## Factions.are_hostile(
##     species1,
##     species2,
##     allegiance1,
##     allegiance2
## )
##
## Relationship priority:
##
## 1. Invalid faction memberships are removed.
## 2. Members of the same valid faction are friendly.
## 3. Human-only factions reject and attack non-humans.
## 4. Otherwise, normal species hostility is used.
static func are_hostile(
	species1: Type,
	species2: Type,
	allegiance1: Allegiance = Allegiance.NONE,
	allegiance2: Allegiance = Allegiance.NONE
) -> bool:
	var valid_allegiance1 := normalize_allegiance(
		species1,
		allegiance1
	)

	var valid_allegiance2 := normalize_allegiance(
		species2,
		allegiance2
	)

	# A shared allegiance overrides normal species hostility.
	#
	# A human, orc, demon, and undead Moon cultist will therefore
	# recognize one another as allies.
	if (
		valid_allegiance1 != Allegiance.NONE
		and valid_allegiance1 == valid_allegiance2
	):
		return false

	# Human-only factions reject every non-human creature.
	if (
		is_human_only(valid_allegiance1)
		and species2 != Type.HUMAN
	):
		return true

	if (
		is_human_only(valid_allegiance2)
		and species1 != Type.HUMAN
	):
		return true

	# Different factions currently have no special relationship,
	# so fall back to the natural species relationship.
	return are_species_hostile(species1, species2)


## Convenience method for checking friendliness.
static func are_friendly(
	species1: Type,
	species2: Type,
	allegiance1: Allegiance = Allegiance.NONE,
	allegiance2: Allegiance = Allegiance.NONE
) -> bool:
	return not are_hostile(
		species1,
		species2,
		allegiance1,
		allegiance2
	)
