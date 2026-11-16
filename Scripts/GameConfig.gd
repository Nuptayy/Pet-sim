# GameConfig.gd
extends Node

# --- Définitions Statiques du Jeu ---
const RARITIES = {
	"Common":     {"color": Color.WHITE,          "order": 0,  "chance_below": INF},
	"Uncommon":   {"color": Color.GREEN,          "order": 1,  "chance_below": 40.0},
	"Rare":       {"color": Color.BLUE,           "order": 2,  "chance_below": 20.0},
	"Epic":       {"color": Color.PURPLE,         "order": 3,  "chance_below": 10.0},
	"Legendary":  {"color": Color.ORANGE,         "order": 4,  "chance_below": 5.0},
	"Mythic":     {"color": Color.YELLOW,         "order": 5,  "chance_below": 1.0},
	"Divine":     {"color": Color.SKY_BLUE,       "order": 6,  "chance_below": 0.1},
	"Godly":      {"color": Color.REBECCA_PURPLE, "order": 7,  "chance_below": 0.01},
	"Secret":     {"color": Color.MEDIUM_PURPLE,  "order": 8,  "chance_below": 0.001},
	"Insane":     {"color": Color.DARK_RED,       "order": 9,  "chance_below": 0.0001},
	"WTF":        {"color": Color.GOLD,           "order": 10, "chance_below": 0.00001},
	"Impossible": {"color": Color.BLACK,          "order": 11, "chance_below": 0.000001},
	"???":        {"color": Color.WHITE,          "order": 12, "chance_below": 0.0000001}
}

const PET_TYPES = [
	{"name": "Classic", "chance": 88.89, "effect_type": "none",   "value": null,                                          "order": 0, "stat_multiplier": 1.0},
	{"name": "Golden",  "chance": 10.0,  "effect_type": "shader", "value": "res://Shaders/golden_effect.gdshader",  "order": 1, "stat_multiplier": 1.5},
	{"name": "Rainbow", "chance": 1.0,   "effect_type": "shader", "value": "res://Shaders/rainbow_effect.gdshader", "order": 2, "stat_multiplier": 2.0},
	{"name": "Glitch",  "chance": 0.1,   "effect_type": "shader", "value": "res://Shaders/glitch_effect.gdshader",  "order": 3, "stat_multiplier": 5.0},
	{"name": "Virus",   "chance": 0.01,  "effect_type": "shader", "value": "res://Shaders/virus_effect.gdshader",   "order": 4, "stat_multiplier": 10.0}
]

const PET_DEFINITIONS = {
	"Cat":    {"base_stats": {"CoinBoost": 1.0,  "LuckBoost": 1.0,  "GemBoost": 0.001}, "model": preload("res://Assets/Pets/cat/Cat.glb")},
	"Rabbit": {"base_stats": {"CoinBoost": 2.0,  "LuckBoost": 1.1,  "GemBoost": 0.003}, "model": preload("res://Assets/Pets/Rabbit/Untitled.glb")},
	"Bee":    {"base_stats": {"CoinBoost": 5.0,  "LuckBoost": 1.2,  "GemBoost": 0.008}, "model": preload("res://Assets/Pets/bee/Bee.glb")},
	"Fox":        {"base_stats": {"CoinBoost": 12.0,    "LuckBoost": 1.3,  "GemBoost": 0.02},  "model": preload("res://Assets/Egg.glb")},
	"Phoenix":    {"base_stats": {"CoinBoost": 40.0,    "LuckBoost": 1.6,  "GemBoost": 0.06},  "model": preload("res://Assets/Egg.glb")},
	"Dragon":     {"base_stats": {"CoinBoost": 150.0,   "LuckBoost": 2.2,  "GemBoost": 0.2},   "model": preload("res://Assets/Egg.glb")},
	"Shadow Cat": {"base_stats": {"CoinBoost": 1000.0,  "LuckBoost": 4.0,  "GemBoost": 1.0},   "model": preload("res://Assets/Egg.glb")},
	"Owl":        {"base_stats": {"CoinBoost": 20.0,    "LuckBoost": 1.2,  "GemBoost": 0.015}, "model": preload("res://Assets/Egg.glb")},
	"Wolf":       {"base_stats": {"CoinBoost": 45.0,    "LuckBoost": 1.4,  "GemBoost": 0.03},  "model": preload("res://Assets/Egg.glb")},
	"Golem":      {"base_stats": {"CoinBoost": 100.0,   "LuckBoost": 1.7,  "GemBoost": 0.07},  "model": preload("res://Assets/Egg.glb")},
	"Unicorn":    {"base_stats": {"CoinBoost": 300.0,   "LuckBoost": 2.2,  "GemBoost": 0.2},   "model": preload("res://Assets/Egg.glb")},
	"Griffin":    {"base_stats": {"CoinBoost": 1200.0,  "LuckBoost": 3.0,  "GemBoost": 0.6},   "model": preload("res://Assets/Egg.glb")},
	"Hydra":      {"base_stats": {"CoinBoost": 6000.0,  "LuckBoost": 5.0,  "GemBoost": 2.5},   "model": preload("res://Assets/Egg.glb")},
	"Leviathan":  {"base_stats": {"CoinBoost": 40000.0, "LuckBoost": 10.0, "GemBoost": 10.0},  "model": preload("res://Assets/Egg.glb")}
}

const EGG_DEFINITIONS = [
	{
		"name": "Basic Egg",
		"cost": 10,
		"model": preload("res://Scenes/Egg.tscn"),
		"pets": [
			{"name": "Cat",    "chance": 50.0},
			{"name": "Rabbit", "chance": 30.0},
			{"name": "Bee",    "chance": 15.0},
			{"name": "Fox",        "chance": 4.5},
			{"name": "Phoenix",    "chance": 0.49},
			{"name": "Dragon",     "chance": 0.0099},
			{"name": "Shadow Cat", "chance": 0.0001}
		],
		"secret_pets": ["Shadow Cat"],
		"rewards": {
			"Classic": {"type": "gems",           "value": 250},
			"Golden":  {"type": "gems",           "value": 1000},
			"Rainbow": {"type": "permanent_luck", "value": 0.01},
		}
	},
	{
		"name": "Mystic Egg",
		"cost": 2500,
		"model": preload("res://Scenes/Egg.tscn"),
		"pets": [
			{"name": "Owl",       "chance": 45.0},
			{"name": "Wolf",      "chance": 30.0},
			{"name": "Golem",     "chance": 18.0},
			{"name": "Unicorn",   "chance": 6.5},
			{"name": "Griffin",   "chance": 0.49},
			{"name": "Hydra",     "chance": 0.0099},
			{"name": "Leviathan", "chance": 0.0001}
		],
		"secret_pets": ["Leviathan"],
		"rewards": {
			"Classic": {"type": "gems",           "value": 5000},
			"Golden":  {"type": "gems",           "value": 20000},
			"Rainbow": {"type": "permanent_luck", "value": 0.05},
		}
	}
]

const GEM_UPGRADES = {
	"team_slots": {
		"name": "Extra Team Slot",
		"description": "Ajoute un slot à votre équipe de pets.",
		"cost_formula": "exponential",
		"base_cost": 100,
		"cost_increase_factor": 2.5,
		"max_level": 10,
		"increase_per_level": 1
	},
	"hatch_max": {
		"name": "Increase Hatch Max",
		"description": "Permet d'ouvrir un oeuf de plus à la fois.",
		"cost_formula": "exponential",
		"base_cost": 50,
		"cost_increase_factor": 2.0,
		"max_level": 20,
		"increase_per_level": 1
	},
	"hatch_speed": {
		"name": "Hatch Speed",
		"description": "Augmente la vitesse d'animation d'éclosion de 25% par niveau.",
		"cost_formula": "exponential",
		"base_cost": 200,
		"cost_increase_factor": 2.2,
		"max_level": 10,
		"increase_per_level": 0.25
	},
	"permanent_luck": {
		"name": "Permanent Luck",
		"description": "Augmente votre chance permanente de 10%.",
		"cost_formula": "polynomial",
		"base_cost": 250,
		"cost_exponent": 1.4,
		"cost_multiplier": 5,
		"max_level": -1,
		"increase_per_level": 0.1
	},
	"coin_multiplier": {
		"name": "Coin Multiplier",
		"description": "Multiplie tous les gains de Coins.",
		"cost_formula": "exponential",
		"base_cost": 500,
		"cost_increase_factor": 3.0,
		"max_level": 10,
		"increase_per_level": 0.5
	},
	"inventory_slots": {
		"name": "Inventory Slots",
		"description": "Augmente la capacité maximale de l'inventaire de 500 places.",
		"cost_formula": "exponential",
		"base_cost": 300,
		"cost_increase_factor": 2.0,
		"max_level": 10,
		"increase_per_level": 500
	},
	"offline_rewards": {
		"name": "Auto-Hatch Hors Ligne",
		"description": "Continue à éclore des oeufs et à gagner des monnaies lorsque le jeu est fermé.",
		"cost_formula": "static",
		"base_cost": 5000,
		"max_level": 1,
		"increase_per_level": 0
	},
	"offline_time_limit": {
		"name": "Temps Hors Ligne Max",
		"description": "Augmente la durée maximale des récompenses hors ligne de 12 heures.",
		"cost_formula": "exponential",
		"base_cost": 1000,
		"cost_increase_factor": 3.0,
		"max_level": 12,
		"increase_per_level": 12
	}
}

# --- Constantes de Réglage ---
const DEBUG_MENU_FOR_EVERYONE = true
const FUSION_REQUIRED_AMOUNT = 10
const BASE_INVENTORY_SIZE = 1000
const BASE_TEAM_SIZE = 5
const LOW_TIER_RARITIES = ["Common", "Uncommon", "Rare", "Epic"]
const OFFLINE_EFFICIENCY = 0.25
const OFFLINE_BASE_HOURS = 24
const MAX_OFFLINE_EGGS = 50000


# --- Accès aux Définitions ---

# 🔹 Retourne la définition d'un œuf à partir de son nom, ou un dictionnaire vide.
func get_egg_definition(egg_name: String) -> Dictionary:
	for egg_def in EGG_DEFINITIONS:
		if egg_def.name == egg_name:
			return egg_def
	return {}

# 🔹 Retourne le nom du premier œuf qui contient ce pet, ou une chaîne vide.
func get_source_egg_name(pet_name: String) -> String:
	for egg_def in EGG_DEFINITIONS:
		for pet_in_egg in egg_def.pets:
			if pet_in_egg.name == pet_name:
				return egg_def.name
	return ""

# 🔹 Retourne les infos d'un type de pet à partir de son nom, ou un dictionnaire vide.
func get_type_by_name(type_name: String) -> Dictionary:
	for type_info in PET_TYPES:
		if type_info.name == type_name:
			return type_info
	return {}

# 🔹 Retourne les infos d'un type de pet à partir de son ordre, ou un dictionnaire vide.
func get_type_by_order(type_order: int) -> Dictionary:
	for type_info in PET_TYPES:
		if type_info.order == type_order:
			return type_info
	return {}

# 🔹 Retourne la rareté qui correspond à une chance de base, en pourcentage.
func get_rarity_for_chance(chance: float) -> String:
	var best_name = "Common"
	for rarity_name in RARITIES:
		var rarity_def = RARITIES[rarity_name]
		if chance < rarity_def.chance_below and rarity_def.order > RARITIES[best_name].order:
			best_name = rarity_name
	return best_name

# 🔹 Retourne la rareté d'une espèce de pet, déduite de sa chance de base dans son œuf.
func get_pet_rarity(pet_name: String) -> String:
	return get_rarity_for_chance(get_pet_base_chance(pet_name))

# 🔹 Retourne l'ordre de rareté d'une espèce de pet.
func get_rarity_order(pet_name: String) -> int:
	return RARITIES[get_pet_rarity(pet_name)].order


# --- Calculs sur les Définitions ---

# 🔹 Retourne la chance de base d'un pet dans son œuf d'origine, en pourcentage.
func get_pet_base_chance(pet_name: String) -> float:
	for egg_def in EGG_DEFINITIONS:
		for pet_in_egg in egg_def.pets:
			if pet_in_egg.name == pet_name:
				return pet_in_egg.chance
	return 100.0

# 🔹 Retourne la chance combinée (espèce × type) d'obtenir ce pet, en pourcentage.
func get_combined_chance(pet_data: Dictionary) -> float:
	if pet_data.is_empty():
		return 100.0
	var base_pet_chance = get_pet_base_chance(pet_data.base_name)
	if pet_data.type.name == "Classic":
		return base_pet_chance
	return base_pet_chance * pet_data.type.chance / 100.0

# 🔹 Calcule les stats finales d'un pet selon son espèce et son type.
func calculate_final_stats(pet_base_name: String, pet_type_info: Dictionary) -> Dictionary:
	var final_stats = PET_DEFINITIONS[pet_base_name].base_stats.duplicate()
	for stat_name in final_stats:
		final_stats[stat_name] *= pet_type_info.stat_multiplier
	return final_stats

# 🔹 Calcule le coût d'une amélioration pour passer au niveau suivant, ou -1 si elle est inconnue.
func get_upgrade_cost(upgrade_id: String, current_level: int) -> int:
	if not GEM_UPGRADES.has(upgrade_id):
		return -1
	var upgrade_def = GEM_UPGRADES[upgrade_id]
	match upgrade_def.cost_formula:
		"exponential":
			return int(upgrade_def.base_cost * pow(upgrade_def.cost_increase_factor, current_level))
		"polynomial":
			return upgrade_def.base_cost + int(pow(current_level, upgrade_def.cost_exponent) * upgrade_def.cost_multiplier)
		"static":
			return upgrade_def.base_cost
	return -1

# 🔹 Indique si une amélioration a atteint son niveau maximal.
func is_upgrade_maxed(upgrade_id: String, current_level: int) -> bool:
	var max_level = GEM_UPGRADES[upgrade_id].max_level
	return max_level != -1 and current_level >= max_level

# 🔹 Retourne un dictionnaire avec toutes les améliorations au niveau 0.
func get_default_upgrade_levels() -> Dictionary:
	var levels = {}
	for upgrade_id in GEM_UPGRADES:
		levels[upgrade_id] = 0
	return levels
