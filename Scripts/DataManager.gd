# DataManager.gd
# 🔹 Ce script est un Autoload. Il conserve toutes les données importantes du jeu.
extends Node

# 🔹 Signaux pour communiquer les changements à l'interface.
signal inventory_updated
signal total_pet_count_changed(new_count)

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
	"Cat":    {"base_stats": {"Power": 1, "LuckBoost": 1.0, "SpeedBoost": 1.0}, "rarity": "Common",   "model": preload("res://Assets/Pets/cat/Cat.glb")},
	"Rabbit": {"base_stats": {"Power": 2, "LuckBoost": 1.1, "SpeedBoost": 1.0}, "rarity": "Uncommon", "model": preload("res://Assets/Pets/Rabbit/Untitled.glb")},
	"Bee":    {"base_stats": {"Power": 5, "LuckBoost": 1.2, "SpeedBoost": 1.1}, "rarity": "Epic",     "model": preload("res://Assets/Pets/bee/Bee.glb")},
	"Test1":  {"base_stats": {"Power": 3, "LuckBoost": 1.25,"SpeedBoost": 1.15},"rarity": "Rare",     "model": preload("res://Assets/Egg.glb")},
	"Test2":  {"base_stats": {"Power": 10,"LuckBoost": 1.5, "SpeedBoost": 1.2}, "rarity": "Legendary","model": preload("res://Assets/Egg.glb")},
	"Test3":  {"base_stats": {"Power": 25,"LuckBoost": 2.0, "SpeedBoost": 1.5}, "rarity": "Mythic",   "model": preload("res://Assets/Egg.glb")}
}

# 🔹 Définition des œufs et des pets qu'ils peuvent contenir.
var egg_definitions = [
	{
		"name": "Basic Egg",
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

# 🔹 Interrupteur pour la progression du jeu
var progression_is_active = false
var one_second_timer: Timer

# 🔹 Ajoute un pet UNIQUE à l'inventaire du joueur.
func add_pet_to_inventory(pet_base_name: String, pet_type_info: Dictionary):
	var new_pet_instance = {"unique_id": next_pet_unique_id, "base_name": pet_base_name, "type": pet_type_info, "stats": calculate_final_stats(pet_base_name, pet_type_info)}
	player_inventory.append(new_pet_instance)
	next_pet_unique_id += 1
	inventory_updated.emit()
	total_pet_count_changed.emit(player_inventory.size())

# 🔹 Supprime un pet de l'inventaire en utilisant son ID unique.
func remove_pet_by_id(pet_id: int):
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

# 🔹 Calcule les stats finales d'un pet en appliquant le multiplicateur de son type.
func calculate_final_stats(pet_base_name: String, pet_type_info: Dictionary) -> Dictionary:
	var base_stats = pet_definitions[pet_base_name]["base_stats"].duplicate()
	var multiplier = pet_type_info["stat_multiplier"]
	for stat_name in base_stats:
		base_stats[stat_name] *= multiplier
	return base_stats

func _ready():
	one_second_timer = Timer.new()
	one_second_timer.wait_time = 1.0
	one_second_timer.autostart = true
	one_second_timer.timeout.connect(on_one_second_tick)
	add_child(one_second_timer)

func on_one_second_tick():
	if not progression_is_active:
		return
	
	time_played += 1
	var coins_this_tick = get_coins_per_second()
	coins += coins_this_tick
	total_coins_earned += coins_this_tick

# --- Fonctions "Get" pour que l'UI puisse lire les données ---
func get_total_luck_boost() -> float:
	# TODO: Calculer en fonction des pets équipés
	return 1.0

func get_total_speed_boost() -> float:
	# TODO: Calculer en fonction des pets équipés
	return 1.0

func get_coins_per_second() -> float:
	var base_rate = 1.0
	# TODO: Multiplier par le bonus des pets équipés
	return base_rate

func get_gems_per_second_chance() -> float:
	# TODO: Calculer en fonction des pets équipés
	return 0.0

func get_rarest_pet_owned() -> Dictionary:
	if player_inventory.is_empty():
		return {}

	var rarest_pet_so_far = player_inventory[0]
	var rarest_order = rarities[pet_definitions[rarest_pet_so_far["base_name"]]["rarity"]]["order"]

	for i in range(1, player_inventory.size()):
		var current_pet = player_inventory[i]
		var current_order = rarities[pet_definitions[current_pet["base_name"]]["rarity"]]["order"]
		if current_order > rarest_order:
			rarest_pet_so_far = current_pet
			rarest_order = current_order
			
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
