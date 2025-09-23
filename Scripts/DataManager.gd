# DataManager.gd
# 🔹 Ce script est un Autoload. Il conserve toutes les données importantes du jeu.
extends Node

# 🔹 Signaux pour communiquer les changements à l'interface.
signal inventory_updated
signal total_pet_count_changed(new_count)
signal equipped_pets_changed

var autosave_timer: Timer

# 🔹 Définition des raretés du jeu.
var rarities = {
	"Common":    {"color": Color.WHITE, "order": 0},
	"Uncommon":  {"color": Color.GREEN, "order": 1},
	"Rare":      {"color": Color.BLUE, "order": 2},
	"Epic":      {"color": Color.PURPLE, "order": 3},
	"Legendary": {"color": Color.ORANGE, "order": 4},
	"Mythic":    {"color": Color.YELLOW, "order": 5},
	"Divine":    {"color": Color.SKY_BLUE, "order": 6},
	"Godly":     {"color": Color.REBECCA_PURPLE, "order": 7},
	"Secret":    {"color": Color.MEDIUM_PURPLE, "order": 8},
	"Insane":    {"color": Color.DARK_RED, "order": 9},
	"WTF":       {"color": Color.GOLD, "order": 10},
	"Impossible":{"color": Color.BLACK, "order": 11},
	"???":       {"color": Color.WHITE, "order": 12}
}

# 🔹 Définition des types de pet (Classic, Golden, etc.).
var pet_types = [
	{"name": "Classic", "chance": 88.89, "effect_type": "none",   "value": null,                                    "order": 0, "stat_multiplier": 1.0},
	{"name": "Golden",  "chance": 10.0,  "effect_type": "shader", "value": "res://Shaders/golden_effect.gdshader",  "order": 1, "stat_multiplier": 1.5},
	{"name": "Rainbow", "chance": 1.0,   "effect_type": "shader", "value": "res://Shaders/rainbow_effect.gdshader", "order": 2, "stat_multiplier": 2.0},
	{"name": "Glitch",  "chance": 0.1,   "effect_type": "shader", "value": "res://Shaders/glitch_effect.gdshader",  "order": 3, "stat_multiplier": 5.0},
	{"name": "Virus",   "chance": 0.01,  "effect_type": "shader", "value": "res://Shaders/virus_effect.gdshader",   "order": 4, "stat_multiplier": 10.0}
]

# 🔹 Définition de chaque pet et de ses stats de BASE.
var pet_definitions = {
	"Cat":    {"base_stats": {"CoinBoost": 1, "LuckBoost": 1.0, "SpeedBoost": 1.0}, "rarity": "Common",   "model": preload("res://Assets/Pets/cat/Cat.glb")},
	"Rabbit": {"base_stats": {"CoinBoost": 2, "LuckBoost": 1.1, "SpeedBoost": 1.0}, "rarity": "Uncommon", "model": preload("res://Assets/Pets/Rabbit/Untitled.glb")},
	"Bee":    {"base_stats": {"CoinBoost": 5, "LuckBoost": 1.2, "SpeedBoost": 1.1}, "rarity": "Rare",     "model": preload("res://Assets/Pets/bee/Bee.glb")},
	"Test1":  {"base_stats": {"CoinBoost": 3, "LuckBoost": 1.25,"SpeedBoost": 1.15},"rarity": "Epic",     "model": preload("res://Assets/Egg.glb")},
	"Test2":  {"base_stats": {"CoinBoost": 10,"LuckBoost": 1.5, "SpeedBoost": 1.2}, "rarity": "Legendary","model": preload("res://Assets/Egg.glb")},
	"Test3":  {"base_stats": {"CoinBoost": 25,"LuckBoost": 2.0, "SpeedBoost": 1.5}, "rarity": "Mythic",   "model": preload("res://Assets/Egg.glb")}
}

# 🔹 Définition des œufs et des pets qu'ils peuvent contenir.
var egg_definitions = [
	{
		"name": "Basic Egg",
		"cost": 100,
		"model": preload("res://Scenes/Egg.tscn"),
		"pets": [
			{"name": "Cat",    "chance": 50.0},
			{"name": "Rabbit", "chance": 30.0},
			{"name": "Bee",    "chance": 15.0},
			{"name": "Test1",  "chance": 4.9989},
			{"name": "Test2",  "chance": 0.001},
			{"name": "Test3",  "chance": 0.0001}
		]
	}
]

# 🔹 NOUVELLES DONNÉES DE JOUEUR
var coins: float = 0.0
var gems: int = 0
var time_played: int = 0
var eggs_hatched: int = 0
var total_coins_earned: float = 0.0
var total_gems_earned: int = 0
var equipped_pets: Array[int] = [] # Stocke les unique_id des pets équipés
var discovered_pets: Dictionary = {} # Stocke les noms des pets découverts

# --- Options du joueur (seront chargées depuis la sauvegarde) ---
var option_confirm_delete = true

# 🔹 Inventaire réel du joueur.
var player_inventory: Array[Dictionary] = []
var next_pet_unique_id = 0

# 🔹 Système d'Équipe
var max_equipped_pets: int = 5

# 🔹 Stocke les filtres d'auto-delete.
var auto_delete_filters: Dictionary = {}

# 🔹 Interrupteur pour la progression du jeu
var progression_is_active = false
var one_second_timer: Timer

# 🔹 Ajoute un pet UNIQUE à l'inventaire du joueur.
func add_pet_to_inventory(pet_base_name: String, pet_type_info: Dictionary):
	var new_pet_instance = {
		"unique_id": next_pet_unique_id,
		"base_name": pet_base_name,
		"type": pet_type_info,
		"stats": calculate_final_stats(pet_base_name, pet_type_info)
	}
	player_inventory.append(new_pet_instance)
	next_pet_unique_id += 1
	discover_pet(pet_base_name)
	inventory_updated.emit()
	total_pet_count_changed.emit(player_inventory.size())

# 🔹 Supprime un pet de l'inventaire en utilisant son ID unique.
func remove_pet_by_id(pet_id: int):
	unequip_pet(pet_id)
	for i in range(player_inventory.size()):
		if player_inventory[i]["unique_id"] == pet_id:
			player_inventory.remove_at(i)
			inventory_updated.emit()
			total_pet_count_changed.emit(player_inventory.size())
			return

# 🔹 Récupère les données d'un pet par son ID unique.
func get_pet_by_id(pet_id: int) -> Dictionary:
	for pet in player_inventory:
		if pet["unique_id"] == pet_id:
			return pet
	return {}

# 🔹 Ajoute un pet à l'équipe.
func equip_pet(pet_id: int):
	if equipped_pets.size() < max_equipped_pets and not pet_id in equipped_pets:
		equipped_pets.append(pet_id)
		equipped_pets_changed.emit()

# 🔹 Retire un pet de l'équipe.
func unequip_pet(pet_id: int):
	if pet_id in equipped_pets:
		equipped_pets.erase(pet_id)
		equipped_pets_changed.emit()

# 🔹 Calcule les stats finales d'un pet en appliquant le multiplicateur de son type.
func calculate_final_stats(pet_base_name: String, pet_type_info: Dictionary) -> Dictionary:
	var base_stats = pet_definitions[pet_base_name]["base_stats"].duplicate()
	var multiplier = pet_type_info["stat_multiplier"]
	for stat_name in base_stats:
		base_stats[stat_name] *= multiplier
	return base_stats

func _ready():
	for egg_def in egg_definitions:
		if not auto_delete_filters.has(egg_def["name"]):
			auto_delete_filters[egg_def["name"]] = {}
	
	one_second_timer = Timer.new()
	one_second_timer.wait_time = 1.0
	one_second_timer.autostart = true
	one_second_timer.timeout.connect(on_one_second_tick)
	add_child(one_second_timer)
	autosave_timer = Timer.new()
	autosave_timer.wait_time = 60.0
	autosave_timer.autostart = true
	autosave_timer.timeout.connect(SaveManager.save_all)
	add_child(autosave_timer)

func on_one_second_tick():
	if not progression_is_active:
		return
	
	time_played += 1
	var coins_this_tick = get_coins_per_second()
	coins += coins_this_tick
	total_coins_earned += coins_this_tick

# 🔹 Calcule le multiplicateur de Luck total basé sur l'équipe.
func get_total_luck_boost() -> float:
	var total_multiplier = 1.0
	for pet_id in equipped_pets:
		var pet_instance = get_pet_by_id(pet_id)
		if not pet_instance.is_empty():
			total_multiplier *= pet_instance["stats"]["LuckBoost"]
	return total_multiplier

# 🔹 Calcule le multiplicateur de Vitesse total basé sur l'équipe.
func get_total_speed_boost() -> float:
	var total_multiplier = 1.0
	for pet_id in equipped_pets:
		var pet_instance = get_pet_by_id(pet_id)
		if not pet_instance.is_empty():
			total_multiplier *= pet_instance["stats"]["SpeedBoost"]
	return total_multiplier

# 🔹 Calcule le gain de Coins par seconde basé sur l'équipe.
func get_coins_per_second() -> float:
	var base_rate = 1.0
	var total_multiplier = 1.0
	for pet_id in equipped_pets:
		var pet_instance = get_pet_by_id(pet_id)
		if not pet_instance.is_empty():
			total_multiplier *= pet_instance["stats"]["CoinBoost"]
	return base_rate * total_multiplier

func get_gems_per_second_chance() -> float:
	# TODO: Calculer en fonction des pets équipés
	return 0.0

# 🔹 Calcule la chance combinée (en %) d'obtenir un pet spécifique avec son type.
func get_combined_chance(pet_instance: Dictionary) -> float:
	if pet_instance.is_empty():
		return 100.0
	
	var pet_base_name = pet_instance["base_name"]
	var pet_type_info = pet_instance["type"]
	
	# Récupère la chance de base du pet (depuis le premier œuf, pour l'instant).
	# Note : cette partie devra être améliorée si vous voulez la chance exacte de l'œuf d'origine.
	var base_pet_chance = 100.0
	if not egg_definitions.is_empty():
		for pet_in_egg in egg_definitions[0]["pets"]:
			if pet_in_egg["name"] == pet_base_name:
				base_pet_chance = pet_in_egg["chance"]
				break
	
	if pet_type_info["name"] == "Classic":
		return base_pet_chance
	else:
		var type_chance = pet_type_info["chance"]
		# Formule: (chance_pet / 100) * (chance_type / 100) * 100
		return base_pet_chance * type_chance / 100.0

func get_rarest_pet_owned() -> Dictionary:
	if player_inventory.is_empty():
		return {}
	
	var rarest_pet_so_far = player_inventory[0]
	var rarest_chance = get_combined_chance(rarest_pet_so_far)
	
	for i in range(1, player_inventory.size()):
		var current_pet = player_inventory[i]
		var current_chance = get_combined_chance(current_pet)
		if current_chance < rarest_chance:
			rarest_pet_so_far = current_pet
			rarest_chance = current_chance
			
	return rarest_pet_so_far

func get_index_completion() -> float:
	if pet_definitions.size() == 0:
		return 0.0
	
	var discovered_count = discovered_pets.size()
	var total_pets = pet_definitions.size()
	return (float(discovered_count) / float(total_pets)) * 100.0

# 🔹 Met à jour le nombre d'œufs ouverts.
func increment_eggs_hatched(amount: int):
	eggs_hatched += amount

# 🔹 Marque un pet comme découvert.
func discover_pet(pet_name: String):
	if not discovered_pets.has(pet_name):
		discovered_pets[pet_name] = true
		print("Nouveau pet découvert pour l'Index : ", pet_name)
