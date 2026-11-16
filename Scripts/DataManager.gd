# DataManager.gd
extends Node

# --- Signaux ---
signal inventory_updated
signal total_pet_count_changed(new_count)
signal equipped_pets_changed
signal gems_updated(new_gem_count)
signal upgrades_changed
signal index_status_changed
signal message_emitted(text)

# --- Données de Progression du Joueur ---
var coins: float = 0.0
var gems: int = 0
var time_played: int = 0
var eggs_hatched: int = 0
var total_coins_earned: float = 0.0
var total_gems_earned: int = 0
var rarest_pet_ever_owned: Dictionary = {}

var player_inventory: Array[Dictionary] = []
var equipped_pets: Array[int] = []
var next_pet_unique_id: int = 0
var max_equipped_pets: int = 5

var discovered_pets: Dictionary = {}
var discovered_pet_types: Array[String] = ["Classic"]
var auto_delete_filters: Dictionary = {}
var egg_index_status: Dictionary = {}

var permanent_luck_boost: float = 1.0
var upgrade_levels: Dictionary = {}
var offline_hatch_target: String = ""

# --- État de Session ---
var progression_is_active: bool = false
var debug_luck_override: float = 0.0


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Prépare les structures par défaut de l'état du joueur.
func _ready():
	upgrade_levels = GameConfig.get_default_upgrade_levels()
	max_equipped_pets = GameConfig.BASE_TEAM_SIZE
	ensure_default_structures()


# --- Initialisation et Messages ---

# 🔹 Garantit que chaque œuf possède ses filtres d'auto-delete et ses statuts d'index.
func ensure_default_structures():
	for egg_def in GameConfig.EGG_DEFINITIONS:
		if typeof(auto_delete_filters.get(egg_def.name)) != TYPE_DICTIONARY:
			auto_delete_filters[egg_def.name] = {}
		if typeof(egg_index_status.get(egg_def.name)) != TYPE_DICTIONARY:
			egg_index_status[egg_def.name] = {}
		for type_name in egg_def.rewards:
			if not egg_index_status[egg_def.name].has(type_name):
				egg_index_status[egg_def.name][type_name] = "not_completed"

# 🔹 Envoie un court message à afficher au joueur.
func notify(text: String):
	message_emitted.emit(text)


# --- Monnaies ---

# 🔹 Ajoute des coins au joueur et au total gagné.
func add_coins(amount: float):
	coins += amount
	total_coins_earned += max(0.0, amount)

# 🔹 Retire des coins au joueur.
func spend_coins(amount: float):
	coins = max(0.0, coins - amount)

# 🔹 Ajoute des gems au joueur et au total gagné, puis prévient l'interface.
func add_gems(amount: int):
	if amount == 0:
		return
	gems += amount
	total_gems_earned += maxi(0, amount)
	gems_updated.emit(gems)

# 🔹 Retire des gems au joueur, puis prévient l'interface.
func spend_gems(amount: int):
	gems = maxi(0, gems - amount)
	gems_updated.emit(gems)


# --- Inventaire ---

# 🔹 Retourne le nombre de places encore libres dans l'inventaire.
func get_free_inventory_space() -> int:
	return maxi(0, get_max_inventory_size() - player_inventory.size())

# 🔹 Retourne l'instance de pet correspondant à un identifiant, ou un dictionnaire vide.
func get_pet_by_id(pet_id: int) -> Dictionary:
	for pet in player_inventory:
		if pet.unique_id == pet_id:
			return pet
	return {}

# 🔹 Ajoute un pet à l'inventaire et retourne false si l'inventaire est plein.
func add_pet_to_inventory(pet_base_name: String, pet_type_info: Dictionary, ignore_limit: bool = false) -> bool:
	return apply_inventory_change([], [{"base_name": pet_base_name, "type": pet_type_info}], ignore_limit) == 1

# 🔹 Ajoute plusieurs pets d'un coup avec un seul signal et retourne le nombre ajouté.
func add_pets_to_inventory(pets: Array, ignore_limit: bool = false) -> int:
	return apply_inventory_change([], pets, ignore_limit)

# 🔹 Retire plusieurs pets d'un coup (et de l'équipe s'ils y étaient) avec un seul signal.
func remove_pets_by_ids(pet_ids: Array):
	apply_inventory_change(pet_ids, [], true)

# 🔹 Applique en une fois des retraits et des ajouts de pets, et retourne le nombre de pets ajoutés.
func apply_inventory_change(removed_ids: Array, added_pets: Array, ignore_limit: bool = true) -> int:
	var size_before = player_inventory.size()
	var team_changed = false
	if not removed_ids.is_empty():
		var id_set = {}
		for pet_id in removed_ids:
			id_set[pet_id] = true
		var remaining_pets: Array[Dictionary] = []
		for pet in player_inventory:
			if not id_set.has(pet.unique_id):
				remaining_pets.append(pet)
		player_inventory = remaining_pets
		var remaining_team: Array[int] = []
		for pet_id in equipped_pets:
			if not id_set.has(pet_id):
				remaining_team.append(pet_id)
		team_changed = remaining_team.size() != equipped_pets.size()
		equipped_pets = remaining_team
	var added_count = 0
	for pet_data in added_pets:
		if _append_pet(pet_data.base_name, pet_data.type, ignore_limit):
			added_count += 1
	if added_count > 0 or player_inventory.size() != size_before:
		inventory_updated.emit()
		total_pet_count_changed.emit(player_inventory.size())
	if team_changed:
		equipped_pets_changed.emit()
	return added_count

# 🔹 Ajoute un pet sans émettre de signal.
func _append_pet(pet_base_name: String, pet_type_info: Dictionary, ignore_limit: bool) -> bool:
	if not GameConfig.PET_DEFINITIONS.has(pet_base_name):
		return false
	if not ignore_limit and get_free_inventory_space() <= 0:
		return false
	player_inventory.append({
		"unique_id": next_pet_unique_id,
		"base_name": pet_base_name,
		"type": pet_type_info,
		"stats": GameConfig.calculate_final_stats(pet_base_name, pet_type_info)
	})
	next_pet_unique_id += 1
	return true


# --- Équipe ---

# 🔹 Équipe un pet s'il existe et qu'il reste une place dans l'équipe.
func equip_pet(pet_id: int) -> bool:
	if equipped_pets.size() >= max_equipped_pets or pet_id in equipped_pets:
		return false
	if get_pet_by_id(pet_id).is_empty():
		return false
	equipped_pets.append(pet_id)
	equipped_pets_changed.emit()
	return true

# 🔹 Retire un pet de l'équipe.
func unequip_pet(pet_id: int) -> bool:
	if not pet_id in equipped_pets:
		return false
	equipped_pets.erase(pet_id)
	equipped_pets_changed.emit()
	return true

# 🔹 Vide l'équipe et retourne le nombre de pets retirés.
func unequip_all_pets() -> int:
	var removed_count = equipped_pets.size()
	if removed_count == 0:
		return 0
	equipped_pets.clear()
	equipped_pets_changed.emit()
	return removed_count

# 🔹 Remplace toute l'équipe par une liste de pets, dans la limite des places disponibles.
func set_equipped_pets(pet_ids: Array):
	var new_team: Array[int] = []
	for pet_id in pet_ids:
		if new_team.size() >= max_equipped_pets:
			break
		if not pet_id in new_team and not get_pet_by_id(pet_id).is_empty():
			new_team.append(pet_id)
	equipped_pets = new_team
	equipped_pets_changed.emit()

# 🔹 Nettoie l'équipe des identifiants invalides, en double ou en trop.
func sanitize_team():
	var valid_team: Array[int] = []
	for pet_id in equipped_pets:
		if valid_team.size() >= max_equipped_pets:
			break
		if not pet_id in valid_team and not get_pet_by_id(pet_id).is_empty():
			valid_team.append(pet_id)
	equipped_pets = valid_team


# --- Index ---

# 🔹 Enregistre un pet comme découvert et retourne true si c'est une nouvelle découverte.
func mark_discovered(pet_name: String, type_name: String) -> bool:
	if typeof(discovered_pets.get(pet_name)) != TYPE_DICTIONARY:
		discovered_pets[pet_name] = {}
	if not type_name in discovered_pet_types:
		discovered_pet_types.append(type_name)
	if discovered_pets[pet_name].has(type_name):
		return false
	discovered_pets[pet_name][type_name] = true
	return true

# 🔹 Indique si un pet a déjà été découvert dans un type donné.
func is_discovered(pet_name: String, type_name: String) -> bool:
	var pet_discoveries = discovered_pets.get(pet_name)
	return typeof(pet_discoveries) == TYPE_DICTIONARY and pet_discoveries.has(type_name)

# 🔹 Retourne le statut de la récompense d'index d'un œuf pour un type donné.
func get_index_status(egg_name: String, type_name: String) -> String:
	var egg_statuses = egg_index_status.get(egg_name)
	if typeof(egg_statuses) != TYPE_DICTIONARY:
		return "not_completed"
	return egg_statuses.get(type_name, "not_completed")

# 🔹 Modifie le statut de la récompense d'index d'un œuf, puis prévient l'interface.
func set_index_status(egg_name: String, type_name: String, status: String):
	if typeof(egg_index_status.get(egg_name)) != TYPE_DICTIONARY:
		egg_index_status[egg_name] = {}
	egg_index_status[egg_name][type_name] = status
	index_status_changed.emit()

# 🔹 Indique si au moins une récompense d'index attend d'être réclamée.
func has_index_reward_to_claim() -> bool:
	for egg_statuses in egg_index_status.values():
		if typeof(egg_statuses) == TYPE_DICTIONARY and "ready_to_claim" in egg_statuses.values():
			return true
	return false

# 🔹 Retourne les noms des types déjà découverts, triés par ordre de rareté.
func get_discovered_types() -> Array:
	var types_to_display = []
	for type_name in discovered_pet_types:
		if not GameConfig.get_type_by_name(type_name).is_empty() and not type_name in types_to_display:
			types_to_display.append(type_name)
	types_to_display.sort_custom(func(a, b): return GameConfig.get_type_by_name(a).order < GameConfig.get_type_by_name(b).order)
	return types_to_display

# 🔹 Pourcentage d'espèces découvertes par rapport au nombre total d'espèces.
func get_index_completion() -> float:
	if GameConfig.PET_DEFINITIONS.size() == 0:
		return 0.0
	return (float(discovered_pets.size()) / float(GameConfig.PET_DEFINITIONS.size())) * 100.0


# --- Améliorations ---

# 🔹 Retourne le niveau actuel d'une amélioration.
func get_upgrade_level(upgrade_id: String) -> int:
	return int(upgrade_levels.get(upgrade_id, 0))

# 🔹 Retourne le coût du prochain niveau d'une amélioration.
func get_upgrade_cost(upgrade_id: String) -> int:
	return GameConfig.get_upgrade_cost(upgrade_id, get_upgrade_level(upgrade_id))

# 🔹 Modifie le niveau d'une amélioration, recalcule les stats et prévient l'interface.
func set_upgrade_level(upgrade_id: String, new_level: int):
	upgrade_levels[upgrade_id] = new_level
	recalculate_stats_from_upgrades()
	upgrades_changed.emit()

# 🔹 Recalcule la taille d'équipe et la chance permanente (upgrades + récompenses d'index).
func recalculate_stats_from_upgrades():
	var upgrades = GameConfig.GEM_UPGRADES
	max_equipped_pets = GameConfig.BASE_TEAM_SIZE + upgrades.team_slots.increase_per_level * get_upgrade_level("team_slots")
	permanent_luck_boost = 1.0
	permanent_luck_boost += upgrades.permanent_luck.increase_per_level * get_upgrade_level("permanent_luck")
	permanent_luck_boost += get_index_luck_bonus()
	if debug_luck_override > 0.0:
		permanent_luck_boost = debug_luck_override

# 🔹 Additionne les bonus de chance permanente des récompenses d'index déjà réclamées.
func get_index_luck_bonus() -> float:
	var total_bonus = 0.0
	for egg_def in GameConfig.EGG_DEFINITIONS:
		for type_name in egg_def.rewards:
			var reward = egg_def.rewards[type_name]
			if reward.type == "permanent_luck" and get_index_status(egg_def.name, type_name) == "claimed":
				total_bonus += reward.value
	return total_bonus


# --- Stats Dérivées ---

# 🔹 Multiplicateur total de chance (pets équipés × bonus permanent).
func get_total_luck_boost() -> float:
	return (1.0 + _sum_equipped_stat("LuckBoost", 1.0)) * permanent_luck_boost

# 🔹 Vitesse d'éclosion donnée par l'amélioration hatch_speed.
func get_total_speed_boost() -> float:
	return 1.0 + GameConfig.GEM_UPGRADES.hatch_speed.increase_per_level * float(get_upgrade_level("hatch_speed"))

# 🔹 Multiplicateur de coins donné par l'amélioration coin_multiplier.
func get_coin_multiplier() -> float:
	return 1.0 + GameConfig.GEM_UPGRADES.coin_multiplier.increase_per_level * float(get_upgrade_level("coin_multiplier"))

# 🔹 Coins gagnés par seconde (CoinBoost des pets équipés × multiplicateur).
func get_coins_per_second() -> float:
	return (1.0 + _sum_equipped_stat("CoinBoost", 1.0)) * get_coin_multiplier()

# 🔹 Gems gagnées par seconde (somme des GemBoost des pets équipés).
func get_gems_per_second() -> float:
	return _sum_equipped_stat("GemBoost", 0.0)

# 🔹 Taille maximale de l'inventaire (base + amélioration inventory_slots).
func get_max_inventory_size() -> int:
	return GameConfig.BASE_INVENTORY_SIZE + GameConfig.GEM_UPGRADES.inventory_slots.increase_per_level * get_upgrade_level("inventory_slots")

# 🔹 Nombre maximal d'œufs ouverts en une fois à partir d'une valeur de base.
func get_hatch_max(base_hatch_max: int) -> int:
	return base_hatch_max + GameConfig.GEM_UPGRADES.hatch_max.increase_per_level * get_upgrade_level("hatch_max")

# 🔹 Additionne une stat des pets équipés, en retirant une valeur neutre à chacun.
func _sum_equipped_stat(stat_name: String, neutral_value: float) -> float:
	var total = 0.0
	for pet_id in equipped_pets:
		var pet = get_pet_by_id(pet_id)
		if not pet.is_empty():
			total += pet.stats[stat_name] - neutral_value
	return total
