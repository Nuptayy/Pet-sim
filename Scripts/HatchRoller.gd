# HatchRoller.gd
extends RefCounted

# --- Tirage des Pets ---

# 🔹 Construit la table de tirage d'un œuf en appliquant le multiplicateur de chance.
static func build_roll_table(egg_name: String, luck_boost: float) -> Array:
	var egg_def = GameConfig.get_egg_definition(egg_name)
	if egg_def.is_empty():
		return []
	var roll_table = []
	var boosted_total = 0.0
	var low_pool = 0.0
	for pet_info in egg_def.pets:
		var is_low_tier = GameConfig.get_rarity_for_chance(pet_info.chance) in GameConfig.LOW_TIER_RARITIES
		var entry = {"name": pet_info.name, "chance": pet_info.chance, "is_low_tier": is_low_tier}
		if is_low_tier:
			low_pool += entry.chance
		else:
			var boost = entry.chance * luck_boost - entry.chance
			boosted_total += boost
			entry.chance += boost
		roll_table.append(entry)
	if low_pool > 0.001:
		for entry in roll_table:
			if entry.is_low_tier:
				entry.chance = max(0.01, entry.chance - boosted_total * (entry.chance / low_pool))
	var total = 0.0
	for entry in roll_table:
		total += entry.chance
	if total <= 0.0:
		return []
	for entry in roll_table:
		entry.chance *= (100.0 / total)
	return roll_table

# 🔹 Tire un pet (espèce + type) dans une table de tirage.
static func roll_one_pet(roll_table: Array, rng: RandomNumberGenerator) -> Dictionary:
	if roll_table.is_empty():
		return {}
	var roll = rng.randf_range(0.0, 100.0)
	var cumulative = 0.0
	for entry in roll_table:
		cumulative += entry.chance
		if roll <= cumulative:
			return {"base_name": entry.name, "type": roll_pet_type(rng)}
	return {"base_name": roll_table.back().name, "type": roll_pet_type(rng)}

# 🔹 Tire le type d'un pet (Classic, Golden, Rainbow...).
static func roll_pet_type(rng: RandomNumberGenerator) -> Dictionary:
	var roll = rng.randf_range(0.0, 100.0)
	var cumulative = 0.0
	for type_info in GameConfig.PET_TYPES:
		cumulative += type_info.chance
		if roll <= cumulative:
			return type_info
	return GameConfig.PET_TYPES[0]
