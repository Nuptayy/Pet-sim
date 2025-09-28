# DataManager.gd
extends Node

# --- Signaux ---
# Communiquent les changements de données au reste de l'application.
signal inventory_updated
signal total_pet_count_changed(new_count)
signal equipped_pets_changed
signal gems_updated(new_gem_count)
signal upgrades_changed
signal index_status_changed

# ==============================================================================
# 1. DÉFINITIONS STATIQUES DU JEU
# Ces données ne changent pas pendant le jeu.
# ==============================================================================

# --- Définitions des Raretés ---
const RARITIES = {
	"Common":     {"color": Color.WHITE, "order": 0},
	"Uncommon":   {"color": Color.GREEN, "order": 1},
	"Rare":       {"color": Color.BLUE, "order": 2},
	"Epic":       {"color": Color.PURPLE, "order": 3},
	"Legendary":  {"color": Color.ORANGE, "order": 4},
	"Mythic":     {"color": Color.YELLOW, "order": 5},
	"Divine":     {"color": Color.SKY_BLUE, "order": 6},
	"Godly":      {"color": Color.REBECCA_PURPLE, "order": 7},
	"Secret":     {"color": Color.MEDIUM_PURPLE, "order": 8},
	"Insane":     {"color": Color.DARK_RED, "order": 9},
	"WTF":        {"color": Color.GOLD, "order": 10},
	"Impossible": {"color": Color.BLACK, "order": 11},
	"???":        {"color": Color.WHITE, "order": 12}
}

# --- Définitions des Types de Pet ---
const PET_TYPES = [
	{"name": "Classic", "chance": 88.89, "effect_type": "none",   "value": null, "order": 0, "stat_multiplier": 1.0},
	{"name": "Golden",  "chance": 10.0,  "effect_type": "shader", "value": "res://Shaders/golden_effect.gdshader", "order": 1, "stat_multiplier": 1.5},
	{"name": "Rainbow", "chance": 1.0,   "effect_type": "shader", "value": "res://Shaders/rainbow_effect.gdshader", "order": 2, "stat_multiplier": 2.0},
	{"name": "Glitch",  "chance": 0.1,   "effect_type": "shader", "value": "res://Shaders/glitch_effect.gdshader", "order": 3, "stat_multiplier": 5.0},
	{"name": "Virus",   "chance": 0.01,  "effect_type": "shader", "value": "res://Shaders/virus_effect.gdshader", "order": 4, "stat_multiplier": 10.0}
]

# --- Définitions des Pets ---
const PET_DEFINITIONS = {
	"Cat":    {"base_stats": {"CoinBoost": 1.0, "LuckBoost": 1.0, "SpeedBoost": 1.0}, "rarity": "Common",    "model": preload("res://Assets/Pets/cat/Cat.glb")},
	"Rabbit": {"base_stats": {"CoinBoost": 2.0, "LuckBoost": 1.1, "SpeedBoost": 1.0}, "rarity": "Uncommon",  "model": preload("res://Assets/Pets/Rabbit/Untitled.glb")},
	"Bee":    {"base_stats": {"CoinBoost": 5.0, "LuckBoost": 1.2, "SpeedBoost": 1.1}, "rarity": "Rare",      "model": preload("res://Assets/Pets/bee/Bee.glb")},
	"Test1":  {"base_stats": {"CoinBoost": 3.0, "LuckBoost": 1.25,"SpeedBoost": 1.15},"rarity": "Epic",      "model": preload("res://Assets/Egg.glb")},
	"Test2":  {"base_stats": {"CoinBoost": 10.0,"LuckBoost": 1.5, "SpeedBoost": 1.2}, "rarity": "Legendary", "model": preload("res://Assets/Egg.glb")},
	"Test3":  {"base_stats": {"CoinBoost": 25.0,"LuckBoost": 2.0, "SpeedBoost": 1.5}, "rarity": "Mythic",    "model": preload("res://Assets/Egg.glb")}
}

# --- Définitions des Œufs ---
const EGG_DEFINITIONS = [
	{
		"name": "Basic Egg",
		"cost": 10,
		"model": preload("res://Scenes/Egg.tscn"),
		"pets": [
			{"name": "Cat",    "chance": 50.0},
			{"name": "Rabbit", "chance": 30.0},
			{"name": "Bee",    "chance": 15.0},
			{"name": "Test1",  "chance": 4.9989},
			{"name": "Test2",  "chance": 0.001},
			{"name": "Test3",  "chance": 0.0001}
		],
		"secret_pets": ["Test3"],
		"rewards": { # <-- "reward" devient "rewards"
			"Classic": {"type": "gems", "value": 250},
			"Golden":  {"type": "gems", "value": 1000},
			"Rainbow": {"type": "permanent_luck", "value": 0.01},
		}
	}
]

# --- Définitions des Améliorations (Gem Shop) ---
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
		"description": "Permet d'ouvrir un œuf de plus à la fois.",
		"cost_formula": "exponential",
		"base_cost": 50,
		"cost_increase_factor": 2.0,
		"max_level": 20,
		"increase_per_level": 1
	},
	"permanent_luck": {
		"name": "Permanent Luck", "description": "Augmente votre chance permanente de 10%.",
		"cost_formula": "polynomial",
		"base_cost": 250,
		"cost_exponent": 1.4,
		"cost_multiplier": 5,
		"max_level": -1,
		"increase_per_level": 0.1
	}
}


# ==============================================================================
# 2. DONNÉES DE PROGRESSION DU JOUEUR
# Ces données sont modifiées pendant le jeu et sauvegardées.
# ==============================================================================

# --- Monnaies et Statistiques Globales ---
var coins: float = 0.0
var gems: int = 0
var time_played: int = 0
var eggs_hatched: int = 0
var total_coins_earned: float = 0.0
var total_gems_earned: int = 0
var rarest_pet_ever_owned: Dictionary = {}

# --- Inventaire et Équipe ---
var player_inventory: Array[Dictionary] = []
var equipped_pets: Array[int] = []
var next_pet_unique_id: int = 0
var max_equipped_pets: int = 5 # Valeur de base, modifiée par les améliorations

# --- Index et Filtres ---
var discovered_pets: Dictionary = {}
var discovered_pet_types: Array[String] = ["Classic"]
var auto_delete_filters: Dictionary = {}
var egg_index_status: Dictionary = {}

# --- Améliorations Permanentes ---
var permanent_luck_boost: float = 1.0 # Valeur de base, modifiée par les améliorations
var upgrade_levels: Dictionary = { "team_slots": 0, "hatch_max": 0, "permanent_luck": 0 }


# ==============================================================================
# 3. LOGIQUE INTERNE
# ==============================================================================

# --- Outils et Contrôles Internes ---
var progression_is_active: bool = false
var rng = RandomNumberGenerator.new()
var one_second_timer: Timer
var autosave_timer: Timer


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Initialise le DataManager, configure les timers et les données par défaut.
func _ready():
	rng.randomize()
	
	# Initialise les dictionnaires de filtres pour chaque œuf s'ils n'existent pas.
	for egg_def in EGG_DEFINITIONS:
		if not auto_delete_filters.has(egg_def.name):
			auto_delete_filters[egg_def.name] = {}
	
	# Initialise les statuts d'index s'ils n'existent pas.
	for egg_def in EGG_DEFINITIONS:
		if not egg_index_status.has(egg_def.name):
			egg_index_status[egg_def.name] = {}
		
		# Pour chaque type de récompense défini pour cet œuf.
		for type_name in egg_def.rewards:
			if not egg_index_status[egg_def.name].has(type_name):
				egg_index_status[egg_def.name][type_name] = "not_completed"
	
	# Crée le timer pour les gains passifs (chaque seconde).
	one_second_timer = Timer.new()
	one_second_timer.wait_time = 1.0
	one_second_timer.autostart = true
	one_second_timer.timeout.connect(on_one_second_tick)
	add_child(one_second_timer)
	
	# Crée le timer pour la sauvegarde automatique.
	autosave_timer = Timer.new()
	autosave_timer.wait_time = 60.0
	autosave_timer.autostart = true
	autosave_timer.timeout.connect(SaveManager.save_all)
	add_child(autosave_timer)


# --- Fonctions de Rappel (Signal Callbacks) ---

# 🔹 Gère la progression passive du jeu chaque seconde (coins, gems, temps de jeu).
func on_one_second_tick():
	if not progression_is_active:
		return
	
	time_played += 1
	var coins_this_tick = get_coins_per_second()
	coins += coins_this_tick
	total_coins_earned += coins_this_tick
	
	# Logique de génération de gems.
	var gems_this_tick = 0
	for pet_id in equipped_pets:
		var pet_instance = get_pet_by_id(pet_id)
		if pet_instance.is_empty(): continue
		
		var combined_chance_percent = get_combined_chance(pet_instance)
		if combined_chance_percent > 0 and combined_chance_percent <= 0.1: # Limite de 1/1000
			var denominator = 1.0 / (combined_chance_percent / 100.0)
			var gem_chance_roll = (denominator / 1000.0) / 1000.0
			
			var guaranteed_gems = floor(gem_chance_roll)
			if guaranteed_gems > 0:
				gems_this_tick += guaranteed_gems
			
			var fractional_chance = gem_chance_roll - guaranteed_gems
			if rng.randf() < fractional_chance:
				gems_this_tick += 1
	
	if gems_this_tick > 0:
		gems += gems_this_tick
		total_gems_earned += gems_this_tick
		gems_updated.emit(gems)


# --- Gestion de l'Inventaire et de l'Équipe ---

# 🔹 Ajoute une nouvelle instance de pet à l'inventaire du joueur.
func add_pet_to_inventory(pet_base_name: String, pet_type_info: Dictionary):
	var new_pet_instance = {
		"unique_id": next_pet_unique_id,
		"base_name": pet_base_name,
		"type": pet_type_info,
		"stats": calculate_final_stats(pet_base_name, pet_type_info)
	}
	player_inventory.append(new_pet_instance)
	next_pet_unique_id += 1
	
	inventory_updated.emit()
	total_pet_count_changed.emit(player_inventory.size())

# 🔹 Supprime un pet de l'inventaire en utilisant son ID unique.
func remove_pet_by_id(pet_id: int):
	unequip_pet(pet_id) # S'assure de le déséquiper d'abord.
	
	for i in range(player_inventory.size()):
		if player_inventory[i].unique_id == pet_id:
			player_inventory.remove_at(i)
			inventory_updated.emit()
			total_pet_count_changed.emit(player_inventory.size())
			return

# 🔹 Équipe un pet, s'il y a de la place dans l'équipe.
func equip_pet(pet_id: int):
	if equipped_pets.size() < max_equipped_pets and not pet_id in equipped_pets:
		equipped_pets.append(pet_id)
		equipped_pets_changed.emit()

# 🔹 Déséquipe un pet de l'équipe.
func unequip_pet(pet_id: int):
	if pet_id in equipped_pets:
		equipped_pets.erase(pet_id)
		equipped_pets_changed.emit()

# 🔹 Récupère toutes les données d'un pet de l'inventaire via son ID unique.
func get_pet_by_id(pet_id: int) -> Dictionary:
	for pet in player_inventory:
		if pet.unique_id == pet_id:
			return pet
	return {}

# 🔹 Fusionne 10 instances d'un pet pour créer une version de type supérieur.
func fuse_pets(base_pet_id: int):
	# 1. Récupérer les informations du pet de base.
	var base_pet = get_pet_by_id(base_pet_id)
	if base_pet.is_empty():
		printerr("Fusion annulée: pet de base non trouvé.")
		return

	var pet_species = base_pet.base_name
	var current_type_order = base_pet.type.order
	var required_amount = 10 # Nombre de pets requis pour la fusion

	# 2. Déterminer le type suivant.
	var next_type_info = null
	for pet_type in PET_TYPES:
		if pet_type.order == current_type_order + 1:
			next_type_info = pet_type
			break
	
	if next_type_info == null:
		print("Fusion impossible: type maximum déjà atteint.")
		return

	# 3. Trouver et collecter les pets à fusionner.
	var candidates_to_fuse = player_inventory.filter(func(p): return p.base_name == pet_species and p.type.order == current_type_order)
	
	if candidates_to_fuse.size() < required_amount:
		print("Fusion annulée: pas assez de pets candidats.")
		return
		
	# 4. Prioriser la suppression des non-équipés.
	var non_equipped_candidates = candidates_to_fuse.filter(func(p): return not p.unique_id in equipped_pets)
	var equipped_candidates = candidates_to_fuse.filter(func(p): return p.unique_id in equipped_pets)
	
	var pets_to_remove: Array[Dictionary] = []
	pets_to_remove.append_array(non_equipped_candidates)
	pets_to_remove.append_array(equipped_candidates)
	
	# Ne prend que le nombre requis.
	pets_to_remove = pets_to_remove.slice(0, required_amount)
	
	# 5. Supprimer les pets consommés.
	for pet_to_remove in pets_to_remove:
		remove_pet_by_id(pet_to_remove.unique_id)
		
	# 6. Ajouter le nouveau pet fusionné.
	add_pet_to_inventory(pet_species, next_type_info)
	
	# 7. Découvrir le nouveau pet fusionné.
	var source_egg_name = ""
	for egg_def in EGG_DEFINITIONS:
		for pet_in_egg in egg_def.pets:
			if pet_in_egg.name == pet_species:
				source_egg_name = egg_def.name
				break
		if not source_egg_name.is_empty():
			break
	
	if not source_egg_name.is_empty():
		discover_pet(pet_species, source_egg_name, next_type_info)

	print("Fusion réussie ! Création de 1x %s %s" % [next_type_info.name, pet_species])

# --- Gestion des Améliorations (Gem Shop) ---

# 🔹 Calcule le coût du prochain niveau pour une amélioration donnée.
func get_upgrade_cost(upgrade_id: String) -> int:
	if not GEM_UPGRADES.has(upgrade_id): return -1

	var upgrade_def = GEM_UPGRADES[upgrade_id]
	var current_level = upgrade_levels.get(upgrade_id, 0)
	var cost = 0

	match upgrade_def.cost_formula:
		"exponential":
			cost = int(upgrade_def.base_cost * pow(upgrade_def.cost_increase_factor, current_level))
		"polynomial":
			cost = upgrade_def.base_cost + int(pow(current_level, upgrade_def.cost_exponent) * upgrade_def.cost_multiplier)

	return cost

# 🔹 Gère la logique d'achat et d'application d'une amélioration.
func purchase_upgrade(upgrade_id: String) -> bool:
	if not GEM_UPGRADES.has(upgrade_id):
		printerr("Tentative d'achat d'une amélioration inconnue: ", upgrade_id)
		return false
	
	var upgrade_def = GEM_UPGRADES[upgrade_id]
	var current_level = upgrade_levels.get(upgrade_id, 0)
	
	# Vérifie si le niveau maximum est atteint.
	if upgrade_def.max_level != -1 and current_level >= upgrade_def.max_level:
		print("Niveau max atteint pour ", upgrade_id)
		return false
	
	# Calcule le coût et vérifie les fonds.
	var cost = get_upgrade_cost(upgrade_id)
	if cost == -1 or gems < cost:
		print("Achat impossible pour ", upgrade_id)
		return false
	
	# Applique la transaction et met à jour les stats.
	gems -= cost
	upgrade_levels[upgrade_id] += 1
	recalculate_stats_from_upgrades() # Recalcule les stats internes au DataManager.
	
	gems_updated.emit(gems)
	upgrades_changed.emit()
	SaveManager.save_game_data()
	print("Amélioration '%s' achetée ! Nouveau niveau: %d" % [upgrade_id, upgrade_levels[upgrade_id]])
	return true

# 🔹 Recalcule les stats affectées par les améliorations (appelé au chargement et à l'achat).
func recalculate_stats_from_upgrades():
	# Réinitialise aux valeurs de base.
	max_equipped_pets = 5
	permanent_luck_boost = 1.0
	
	# Applique le bonus des slots d'équipe.
	var team_slots_level = upgrade_levels.get("team_slots", 0)
	if team_slots_level > 0:
		max_equipped_pets += GEM_UPGRADES.team_slots.increase_per_level * team_slots_level
	
	# Applique le bonus de chance permanente.
	var perm_luck_level = upgrade_levels.get("permanent_luck", 0)
	if perm_luck_level > 0:
		permanent_luck_boost += GEM_UPGRADES.permanent_luck.increase_per_level * perm_luck_level
	
	print("Stats permanentes recalculées à partir des niveaux d'amélioration.")


# --- Gets et Calculs de Stats ---

# 🔹 Calcule le multiplicateur total de chance (pets équipés + bonus permanent).
func get_total_luck_boost() -> float:
	var base_luck = 1.0
	var total_pet_bonus = 0.0
	
	for pet_id in equipped_pets:
		var pet_instance = get_pet_by_id(pet_id)
		if not pet_instance.is_empty():
			total_pet_bonus += (pet_instance.stats.LuckBoost - 1.0)
	
	# On applique le bonus permanent à la fin
	return (base_luck + total_pet_bonus) * permanent_luck_boost

# 🔹 Calcule le multiplicateur total de vitesse d'éclosion.
func get_total_speed_boost() -> float:
	var base_speed = 1.0
	var total_bonus = 0.0
	
	for pet_id in equipped_pets:
		var pet_instance = get_pet_by_id(pet_id)
		if not pet_instance.is_empty():
			total_bonus += (pet_instance.stats.SpeedBoost - 1.0)
			
	return base_speed + total_bonus

# 🔹 Calcule le gain total de pièces par seconde.
func get_coins_per_second() -> float:
	var base_rate = 1.0
	var total_bonus = 0.0
	
	for pet_id in equipped_pets:
		var pet_instance = get_pet_by_id(pet_id)
		if not pet_instance.is_empty():
			total_bonus += (pet_instance.stats.CoinBoost - 1.0)
			
	return base_rate + total_bonus

# 🔹 Calcule le taux de génération de gemmes attendu par seconde (pour affichage).
func get_gems_per_second_chance() -> float:
	var total_chance_per_second = 0.0
	for pet_id in equipped_pets:
		var pet_instance = get_pet_by_id(pet_id)
		if pet_instance.is_empty(): continue
		
		var combined_chance_percent = get_combined_chance(pet_instance)
		if combined_chance_percent > 0 and combined_chance_percent <= 0.1:
			var denominator = 1.0 / (combined_chance_percent / 100.0)
			total_chance_per_second += (denominator / 1000.0) / 1000.0
	
	return total_chance_per_second * 100.0

# 🔹 Calcule le bonus à ajouter au nombre maximal d'œufs à éclore.
func get_hatch_max_bonus() -> int:
	var level = upgrade_levels.get("hatch_max", 0)
	return GEM_UPGRADES.hatch_max.increase_per_level * level

# 🔹 Calcule les statistiques finales d'un pet en appliquant son multiplicateur de type.
func calculate_final_stats(pet_base_name: String, pet_type_info: Dictionary) -> Dictionary:
	var base_stats = PET_DEFINITIONS[pet_base_name].base_stats.duplicate()
	var multiplier = pet_type_info.stat_multiplier
	for stat_name in base_stats:
		base_stats[stat_name] *= multiplier
	return base_stats

# 🔹 Calcule la chance combinée (en %) d'obtenir un pet spécifique avec son type.
func get_combined_chance(pet_instance: Dictionary) -> float:
	if pet_instance.is_empty(): return 100.0
	
	var pet_base_name = pet_instance.base_name
	var pet_type_info = pet_instance.type
	var base_pet_chance = 100.0
	
	# TODO: Améliorer ce système pour trouver la chance dans l'œuf d'origine du pet.
	if not EGG_DEFINITIONS.is_empty():
		for pet_in_egg in EGG_DEFINITIONS[0].pets:
			if pet_in_egg.name == pet_base_name:
				base_pet_chance = pet_in_egg.chance
				break
	
	if pet_type_info.name == "Classic":
		return base_pet_chance
	else:
		return base_pet_chance * pet_type_info.chance / 100.0

# 🔹 Récupère tous les types de pets uniques que le joueur a déjà possédés.
func get_discovered_types() -> Array:
	var discovered_types: Array = []
	
	for pet_instance in player_inventory:
		var type_name = pet_instance.type.name
		if not type_name in discovered_types:
			discovered_types.append(type_name)
			
	# Assure que le type "Classic" est toujours présent, même si l'inventaire est vide.
	if not "Classic" in discovered_types:
		discovered_types.insert(0, "Classic")
		
	# Trie la liste selon l'ordre défini dans PET_TYPES pour un affichage cohérent.
	discovered_types.sort_custom(
		func(a, b):
			var order_a = PET_TYPES.filter(func(t): return t.name == a).front().order
			var order_b = PET_TYPES.filter(func(t): return t.name == b).front().order
			return order_a < order_b
	)
	
	return discovered_types


# --- Gestion de la Progression et de l'Index ---

# 🔹 Met à jour le compteur total d'œufs éclos.
func increment_eggs_hatched(amount: int):
	eggs_hatched += amount

# 🔹 Marque un pet comme "découvert" dans l'index du joueur.
func discover_pet(pet_name: String, egg_name: String, type_info: Dictionary):
	var type_name_param = type_info.name
	
	# 1. Découverte de la paire espèce/type
	var is_new_discovery = false
	if not discovered_pets.has(pet_name):
		discovered_pets[pet_name] = {}
	
	if not discovered_pets[pet_name].has(type_name_param):
		discovered_pets[pet_name][type_name_param] = true
		is_new_discovery = true
		print("Nouvelle découverte : %s (%s)" % [pet_name, type_name_param])

	# 2. Découverte du type global (pour les onglets)
	if not type_name_param in discovered_pet_types:
		discovered_pet_types.append(type_name_param)
		print("Nouveau TYPE de pet découvert : ", type_name_param)
		
	# 3. Vérification de la complétion (uniquement si une vraie nouvelle découverte a eu lieu)
	if is_new_discovery:
		_check_for_index_completion(egg_name, type_name_param)

	# 4. Vérification du record de rareté
	var new_pet_instance = { "base_name": pet_name, "type": type_info }
	var new_pet_chance = get_combined_chance(new_pet_instance)
	var current_rarest_chance = get_combined_chance(rarest_pet_ever_owned)

	if new_pet_chance < current_rarest_chance:
		rarest_pet_ever_owned = new_pet_instance
		print("NOUVEAU RECORD: Pet le plus rare jamais obtenu ! ", rarest_pet_ever_owned)

# 🔹 Trouve le pet le plus rare possédé par le joueur.
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

# 🔹 Calcule le pourcentage de complétion de l'index des pets.
func get_index_completion() -> float:
	if PET_DEFINITIONS.size() == 0:
		return 0.0
	
	var discovered_count = discovered_pets.size()
	var total_pets = PET_DEFINITIONS.size()
	return (float(discovered_count) / float(total_pets)) * 100.0

# 🔹 Vérifie si l'index d'un œuf est complété après une nouvelle découverte.
func _check_for_index_completion(egg_name: String, type_name_to_check: String):
	var egg_def_array = EGG_DEFINITIONS.filter(func(e): return e.name == egg_name)
	if egg_def_array.is_empty(): return
	var egg_def = egg_def_array.front()

	# On vérifie si une récompense est définie pour ce type, sinon on ne fait rien.
	if not egg_def.rewards.has(type_name_to_check):
		return

	# Si le statut n'est pas "not_completed", on arrête.
	var current_status = "not_completed"
	var egg_statuses = egg_index_status.get(egg_name, {})
	if typeof(egg_statuses) == TYPE_DICTIONARY and egg_statuses.has(type_name_to_check):
		current_status = egg_statuses[type_name_to_check]
	if current_status != "not_completed":
		return

	# On vérifie si tous les pets requis ont été découverts DANS CE TYPE.
	var all_pets_for_type_discovered = true
	var required_pets = egg_def.pets.map(func(p): return p.name)
	for secret_pet_name in egg_def.secret_pets:
		required_pets.erase(secret_pet_name)
	
	for pet_name in required_pets:
		if not (discovered_pets.has(pet_name) and discovered_pets[pet_name].has(type_name_to_check)):
			all_pets_for_type_discovered = false
			break
			
	if all_pets_for_type_discovered:
		print("Index pour '%s' (%s) complété ! Prêt à être réclamé." % [egg_name, type_name_to_check])
		egg_index_status[egg_name][type_name_to_check] = "ready_to_claim"
		index_status_changed.emit()

# 🔹 Gère la réclamation de la récompense d'un index d'œuf.
func claim_index_reward(egg_name: String, type_name: String):
	var current_status = "not_completed"
	var egg_statuses = egg_index_status.get(egg_name)
	
	if typeof(egg_statuses) == TYPE_DICTIONARY and egg_statuses.has(type_name):
		current_status = egg_statuses[type_name]
	
	if current_status != "ready_to_claim":
		printerr("Tentative de réclamer une récompense non prête pour l'œuf: %s, type: %s" % [egg_name, type_name])
		return
	
	var egg_def_array = EGG_DEFINITIONS.filter(func(e): return e.name == egg_name)
	if egg_def_array.is_empty(): return
	var egg_def = egg_def_array.front()
	
	var reward = egg_def.rewards[type_name]
	
	# Applique la récompense
	match reward.type:
		"gems":
			gems += reward.value
			total_gems_earned += reward.value
			gems_updated.emit(gems)
		"coins":
			coins += reward.value
			total_coins_earned += reward.value
		"permanent_luck":
			permanent_luck_boost += reward.value
			upgrades_changed.emit()
	
	print("Récompense de %s %s réclamée pour l'index de '%s' (%s) !" % [reward.value, reward.type, egg_name, type_name])
	
	egg_index_status[egg_name][type_name] = "claimed"
	index_status_changed.emit()
	SaveManager.save_game_data()


# ==============================================================================
# 4. FONCTIONS DE DÉBOGAGE
# ==============================================================================

# 🔹 [DEBUG] Ajoute un montant de pièces.
func debug_add_coins(amount: float):
	coins += amount
	print("DEBUG: Added %f coins." % amount)

# 🔹 [DEBUG] Ajoute un montant de gemmes.
func debug_add_gems(amount: int):
	gems += amount
	gems_updated.emit(gems)
	print("DEBUG: Added %d gems." % amount)

# 🔹 [DEBUG] Définit une nouvelle valeur pour le multiplicateur de chance permanent.
func debug_set_luck(new_luck_value: float):
	permanent_luck_boost = new_luck_value
	upgrades_changed.emit() # Pour que l'UI se mette à jour
	print("DEBUG: Permanent luck set to %f." % new_luck_value)
