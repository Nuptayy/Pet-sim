# LocalBackend.gd
extends Node

# --- Constantes ---
const HatchRoller = preload("res://Scripts/HatchRoller.gd")
const AUTOSAVE_INTERVAL = 60.0
const MIN_OFFLINE_SECONDS = 60
const EQUIP_BEST_STATS = ["CoinBoost", "LuckBoost", "GemBoost"]

# --- État Interne ---
var _rng = RandomNumberGenerator.new()
var _pending_offline_rewards: Dictionary = {}


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Prépare le générateur aléatoire et les timers de gains passifs et d'autosave.
func _ready():
	_rng.randomize()
	_start_timer(1.0, _on_one_second_tick)
	_start_timer(AUTOSAVE_INTERVAL, SaveManager.save_all)

# 🔹 Crée un timer répétitif relié à une fonction.
func _start_timer(wait_time: float, callback: Callable):
	var timer = Timer.new()
	timer.wait_time = wait_time
	timer.autostart = true
	timer.timeout.connect(callback)
	add_child(timer)


# --- Résultats ---

# 🔹 Construit un résultat de réussite, avec des données supplémentaires facultatives.
func _ok(extra: Dictionary = {}) -> Dictionary:
	var result = {"ok": true}
	result.merge(extra)
	return result

# 🔹 Construit un résultat d'échec, avec un message facultatif à montrer au joueur.
func _fail(error_code: String, message: String = "") -> Dictionary:
	return {"ok": false, "error": error_code, "message": message}


# --- Gains Passifs ---

# 🔹 Applique chaque seconde les gains passifs de coins et de gems.
func _on_one_second_tick():
	if not DataManager.progression_is_active:
		return
	DataManager.time_played += 1
	DataManager.add_coins(DataManager.get_coins_per_second())
	var gem_rate = DataManager.get_gems_per_second()
	if gem_rate <= 0.0:
		return
	var gain = floori(gem_rate)
	if _rng.randf() < (gem_rate - float(gain)):
		gain += 1
	DataManager.add_gems(gain)


# --- Éclosion ---

# 🔹 Paie, tire et crédite les pets d'une éclosion, puis retourne la liste des pets tirés.
func hatch(egg_name: String, requested_count: int) -> Dictionary:
	var egg_def = GameConfig.get_egg_definition(egg_name)
	if egg_def.is_empty():
		return _fail("unknown_egg")
	var count = mini(requested_count, DataManager.get_free_inventory_space())
	if count <= 0:
		return _fail("inventory_full", "Inventaire plein !")
	var total_cost = egg_def.cost * count
	if DataManager.coins < total_cost:
		return _fail("not_enough_coins", "Pas assez de Coins ! (%d requis)" % total_cost)
	DataManager.spend_coins(total_cost)
	DataManager.eggs_hatched += count
	var roll_table = HatchRoller.build_roll_table(egg_name, DataManager.get_total_luck_boost())
	var hatched_pets = []
	var kept_pets = []
	for i in range(count):
		var pet_data = HatchRoller.roll_one_pet(roll_table, _rng)
		if pet_data.is_empty():
			continue
		_discover_pet(pet_data.base_name, egg_name, pet_data.type)
		pet_data["to_be_deleted"] = _should_auto_delete(egg_name, pet_data)
		hatched_pets.append(pet_data)
		if not pet_data.to_be_deleted:
			kept_pets.append(pet_data)
	DataManager.add_pets_to_inventory(kept_pets)
	SaveManager.request_save()
	return _ok({"pets": hatched_pets, "cost": total_cost})

# 🔹 Indique si un pet tiré doit être supprimé par les filtres d'auto-delete de son œuf.
func _should_auto_delete(egg_name: String, pet_data: Dictionary) -> bool:
	var filters = DataManager.auto_delete_filters.get(egg_name, {})
	if typeof(filters) != TYPE_DICTIONARY:
		return false
	var rarity_name = GameConfig.get_pet_rarity(pet_data.base_name)
	return filters.has(rarity_name) and pet_data.type.name in filters[rarity_name]


# --- Équipe ---

# 🔹 Équipe un pet de l'inventaire.
func equip_pet(pet_id: int) -> Dictionary:
	if DataManager.equipped_pets.size() >= DataManager.max_equipped_pets:
		return _fail("team_full", "Équipe pleine !")
	if not DataManager.equip_pet(pet_id):
		return _fail("cannot_equip")
	SaveManager.request_save()
	return _ok()

# 🔹 Retire un pet de l'équipe.
func unequip_pet(pet_id: int) -> Dictionary:
	if not DataManager.unequip_pet(pet_id):
		return _fail("not_equipped")
	SaveManager.request_save()
	return _ok()

# 🔹 Retire tous les pets de l'équipe.
func unequip_all_pets() -> Dictionary:
	var removed_count = DataManager.unequip_all_pets()
	if removed_count == 0:
		return _fail("nothing_equipped")
	SaveManager.request_save()
	return _ok({"unequipped": removed_count})

# 🔹 Remplace l'équipe par les pets qui ont la meilleure valeur pour une stat donnée.
func equip_best_pets(stat_name: String) -> Dictionary:
	if not stat_name in EQUIP_BEST_STATS:
		return _fail("unknown_stat")
	if DataManager.player_inventory.is_empty():
		return _fail("no_pets", "Aucun pet à équiper.")
	var ranked_pets = DataManager.player_inventory.duplicate()
	ranked_pets.sort_custom(func(a, b):
		if a.stats[stat_name] != b.stats[stat_name]:
			return a.stats[stat_name] > b.stats[stat_name]
		return a.unique_id < b.unique_id)
	var best_ids = []
	for pet in ranked_pets.slice(0, DataManager.max_equipped_pets):
		best_ids.append(pet.unique_id)
	DataManager.set_equipped_pets(best_ids)
	SaveManager.request_save()
	return _ok({"equipped": best_ids.size()})


# --- Fusion et Suppression ---

# 🔹 Fusionne 10 pets non équipés identiques en un pet du type supérieur.
func fuse_pets(base_pet_id: int) -> Dictionary:
	var base_pet = DataManager.get_pet_by_id(base_pet_id)
	if base_pet.is_empty():
		return _fail("unknown_pet")
	var pet_species: String = base_pet.base_name
	var current_type_order: int = base_pet.type.order
	var next_type_info = GameConfig.get_type_by_order(current_type_order + 1)
	if next_type_info.is_empty():
		return _fail("max_type")
	var ids_to_remove = []
	for pet in DataManager.player_inventory:
		if ids_to_remove.size() >= GameConfig.FUSION_REQUIRED_AMOUNT:
			break
		if pet.base_name == pet_species and pet.type.order == current_type_order and not pet.unique_id in DataManager.equipped_pets:
			ids_to_remove.append(pet.unique_id)
	if ids_to_remove.size() < GameConfig.FUSION_REQUIRED_AMOUNT:
		return _fail("not_enough_pets")
	_discover_pet(pet_species, GameConfig.get_source_egg_name(pet_species), next_type_info)
	DataManager.apply_inventory_change(ids_to_remove, [{"base_name": pet_species, "type": next_type_info}])
	SaveManager.request_save()
	return _ok({"fusions": 1})

# 🔹 Fusionne en cascade tous les pets non équipés et retourne le nombre de fusions effectuées.
func fuse_all_pets() -> Dictionary:
	var type_count = GameConfig.PET_TYPES.size()
	var buckets = {}
	for pet in DataManager.player_inventory:
		if pet.unique_id in DataManager.equipped_pets:
			continue
		if not buckets.has(pet.base_name):
			var ids_per_order = []
			for i in range(type_count):
				ids_per_order.append([])
			buckets[pet.base_name] = ids_per_order
		buckets[pet.base_name][pet.type.order].append(pet.unique_id)
	var ids_to_remove = []
	var pets_to_create = []
	var total_fusions = 0
	for pet_species in buckets:
		var carried_count = 0
		for type_order in range(type_count):
			var owned_ids: Array = buckets[pet_species][type_order]
			var fusions = 0
			if not GameConfig.get_type_by_order(type_order + 1).is_empty():
				fusions = floori((owned_ids.size() + carried_count) / float(GameConfig.FUSION_REQUIRED_AMOUNT))
			var consumed = fusions * GameConfig.FUSION_REQUIRED_AMOUNT
			var consumed_from_carried = mini(carried_count, consumed)
			ids_to_remove.append_array(owned_ids.slice(0, consumed - consumed_from_carried))
			for i in range(carried_count - consumed_from_carried):
				pets_to_create.append({"base_name": pet_species, "type": GameConfig.get_type_by_order(type_order)})
			total_fusions += fusions
			carried_count = fusions
	if total_fusions == 0:
		return _fail("nothing_to_fuse", "Rien à fusionner.")
	for pet_data in pets_to_create:
		_discover_pet(pet_data.base_name, GameConfig.get_source_egg_name(pet_data.base_name), pet_data.type)
	DataManager.apply_inventory_change(ids_to_remove, pets_to_create)
	SaveManager.request_save()
	return _ok({"fusions": total_fusions})

# 🔹 Supprime des pets de l'inventaire, en épargnant ceux qui sont équipés.
func delete_pets(pet_ids: Array) -> Dictionary:
	var ids_to_remove = []
	for pet_id in pet_ids:
		if not pet_id in DataManager.equipped_pets:
			ids_to_remove.append(pet_id)
	if ids_to_remove.is_empty():
		return _fail("nothing_to_delete")
	DataManager.remove_pets_by_ids(ids_to_remove)
	SaveManager.request_save()
	return _ok({"deleted": ids_to_remove.size()})


# --- Améliorations ---

# 🔹 Achète un niveau d'amélioration si le joueur a assez de gems.
func buy_upgrade(upgrade_id: String) -> Dictionary:
	if not GameConfig.GEM_UPGRADES.has(upgrade_id):
		return _fail("unknown_upgrade")
	var current_level = DataManager.get_upgrade_level(upgrade_id)
	if GameConfig.is_upgrade_maxed(upgrade_id, current_level):
		return _fail("max_level")
	var cost = GameConfig.get_upgrade_cost(upgrade_id, current_level)
	if cost < 0 or DataManager.gems < cost:
		return _fail("not_enough_gems", "Pas assez de Gems !")
	DataManager.spend_gems(cost)
	DataManager.set_upgrade_level(upgrade_id, current_level + 1)
	SaveManager.request_save()
	return _ok({"level": current_level + 1})


# --- Index ---

# 🔹 Réclame la récompense d'index d'un œuf pour un type donné.
func claim_index_reward(egg_name: String, type_name: String) -> Dictionary:
	var egg_def = GameConfig.get_egg_definition(egg_name)
	if egg_def.is_empty() or not egg_def.rewards.has(type_name):
		return _fail("unknown_reward")
	if DataManager.get_index_status(egg_name, type_name) != "ready_to_claim":
		return _fail("not_ready")
	var reward = egg_def.rewards[type_name]
	DataManager.set_index_status(egg_name, type_name, "claimed")
	match reward.type:
		"gems":
			DataManager.add_gems(reward.value)
		"coins":
			DataManager.add_coins(reward.value)
		"permanent_luck":
			DataManager.recalculate_stats_from_upgrades()
			DataManager.upgrades_changed.emit()
	SaveManager.request_save()
	return _ok({"reward": reward})

# 🔹 Enregistre la découverte d'un pet et met à jour l'index et le record de rareté.
func _discover_pet(pet_name: String, egg_name: String, type_info: Dictionary):
	if DataManager.mark_discovered(pet_name, type_info.name):
		_check_for_index_completion(egg_name, type_info.name)
	var new_pet = {"base_name": pet_name, "type": type_info}
	if GameConfig.get_combined_chance(new_pet) < GameConfig.get_combined_chance(DataManager.rarest_pet_ever_owned):
		DataManager.rarest_pet_ever_owned = new_pet

# 🔹 Passe la récompense d'un œuf à "prête" si tous ses pets non secrets sont découverts dans ce type.
func _check_for_index_completion(egg_name: String, type_name: String):
	var egg_def = GameConfig.get_egg_definition(egg_name)
	if egg_def.is_empty() or not egg_def.rewards.has(type_name):
		return
	if DataManager.get_index_status(egg_name, type_name) != "not_completed":
		return
	for pet_in_egg in egg_def.pets:
		if not pet_in_egg.name in egg_def.secret_pets and not DataManager.is_discovered(pet_in_egg.name, type_name):
			return
	DataManager.set_index_status(egg_name, type_name, "ready_to_claim")


# --- Réglages du Joueur ---

# 🔹 Remplace les filtres d'auto-delete d'un œuf (rareté -> liste de types).
func set_auto_delete_filters(egg_name: String, filters: Dictionary) -> Dictionary:
	if GameConfig.get_egg_definition(egg_name).is_empty():
		return _fail("unknown_egg")
	var clean_filters = {}
	for rarity_name in filters:
		if GameConfig.RARITIES.has(rarity_name) and not filters[rarity_name].is_empty():
			clean_filters[rarity_name] = filters[rarity_name]
	DataManager.auto_delete_filters[egg_name] = clean_filters
	SaveManager.request_save()
	return _ok()

# 🔹 Définit l'œuf ouvert automatiquement pendant que le jeu est fermé.
func set_offline_hatch_target(egg_name: String) -> Dictionary:
	if GameConfig.get_egg_definition(egg_name).is_empty():
		return _fail("unknown_egg")
	DataManager.offline_hatch_target = egg_name
	SaveManager.request_save()
	return _ok()


# --- Récompenses Hors Ligne ---

# 🔹 Calcule les récompenses de l'absence du joueur et les garde en attente de réclamation.
func get_pending_offline_rewards() -> Dictionary:
	_pending_offline_rewards = {}
	var duration = _get_offline_duration()
	if duration < MIN_OFFLINE_SECONDS:
		return _ok({"has_rewards": false})
	var rewards = _simulate_offline_progress(duration)
	if rewards.net_coin_gain <= 0.0 and rewards.earned_gems <= 0 and rewards.eggs_hatched <= 0:
		return _ok({"has_rewards": false})
	_pending_offline_rewards = rewards
	return _ok({"has_rewards": true, "rewards": rewards})

# 🔹 Applique au joueur les récompenses hors ligne en attente.
func claim_offline_rewards() -> Dictionary:
	if _pending_offline_rewards.is_empty():
		return _fail("no_pending_rewards")
	_apply_offline_gains(_pending_offline_rewards)
	_pending_offline_rewards = {}
	SaveManager.save_game_data()
	return _ok()

# 🔹 Retourne la durée d'absence à récompenser en secondes (0 si rien à calculer).
func _get_offline_duration() -> int:
	if DataManager.get_upgrade_level("offline_rewards") <= 0:
		return 0
	var last_timestamp = SaveManager.load_session_timestamp()
	if last_timestamp <= 0:
		return 0
	var bonus_hours = GameConfig.GEM_UPGRADES.offline_time_limit.increase_per_level * DataManager.get_upgrade_level("offline_time_limit")
	var max_duration = (GameConfig.OFFLINE_BASE_HOURS + bonus_hours) * 3600
	return clampi(int(Time.get_unix_time_from_system()) - last_timestamp, 0, max_duration)

# 🔹 Calcule les gains d'une absence sans les appliquer (coins, gems, œufs, pets gardés).
func _simulate_offline_progress(duration_seconds: int) -> Dictionary:
	var target = DataManager.offline_hatch_target
	var total_earned_coins = DataManager.get_coins_per_second() * GameConfig.OFFLINE_EFFICIENCY * duration_seconds
	var earned_gems = int(DataManager.get_gems_per_second() * duration_seconds * GameConfig.OFFLINE_EFFICIENCY)
	var egg_def = GameConfig.get_egg_definition(target)
	var eggs_count = 0
	var coins_spent = 0.0
	if not egg_def.is_empty() and egg_def.cost > 0:
		eggs_count = int(min(floor((total_earned_coins / 2.0) / egg_def.cost), float(GameConfig.MAX_OFFLINE_EGGS)))
		coins_spent = float(eggs_count) * egg_def.cost
	var kept_pets = []
	var discoveries = {}
	if eggs_count > 0:
		var roll_table = HatchRoller.build_roll_table(target, DataManager.get_total_luck_boost())
		for i in range(eggs_count):
			var pet_data = HatchRoller.roll_one_pet(roll_table, _rng)
			if pet_data.is_empty():
				continue
			var key = "%s_%s" % [pet_data.base_name, pet_data.type.name]
			if not discoveries.has(key):
				discoveries[key] = {"base_name": pet_data.base_name, "type": pet_data.type, "chance": GameConfig.get_combined_chance(pet_data)}
			pet_data["chance"] = discoveries[key].chance
			if not _should_auto_delete(target, pet_data):
				kept_pets.append(pet_data)
	kept_pets.sort_custom(func(a, b): return a.chance < b.chance)
	var free_space = DataManager.get_free_inventory_space()
	if kept_pets.size() > free_space:
		kept_pets = kept_pets.slice(0, free_space)
	return {
		"net_coin_gain": total_earned_coins - coins_spent,
		"earned_gems": earned_gems,
		"eggs_hatched": eggs_count,
		"pets_kept": kept_pets,
		"discoveries": discoveries.values(),
		"best_pets_for_display": kept_pets.slice(0, 4)
	}

# 🔹 Applique au joueur les gains calculés par la simulation hors ligne.
func _apply_offline_gains(rewards: Dictionary):
	DataManager.add_coins(rewards.net_coin_gain)
	DataManager.add_gems(rewards.earned_gems)
	DataManager.eggs_hatched += rewards.eggs_hatched
	for discovery in rewards.discoveries:
		_discover_pet(discovery.base_name, GameConfig.get_source_egg_name(discovery.base_name), discovery.type)
	DataManager.add_pets_to_inventory(rewards.pets_kept)


# --- Commandes de Débogage ---

# 🔹 Ajoute des coins, ou en retire si le montant est négatif.
func debug_add_coins(amount: float) -> Dictionary:
	if amount < 0.0:
		DataManager.spend_coins(-amount)
	else:
		DataManager.add_coins(amount)
	return _ok()

# 🔹 Ajoute des gems, ou en retire si le montant est négatif.
func debug_add_gems(amount: int) -> Dictionary:
	if amount < 0:
		DataManager.spend_gems(-amount)
	else:
		DataManager.add_gems(amount)
	return _ok()

# 🔹 Force la chance permanente à une valeur précise jusqu'à la fermeture du jeu.
func debug_set_luck(new_luck_value: float) -> Dictionary:
	DataManager.debug_luck_override = new_luck_value
	DataManager.recalculate_stats_from_upgrades()
	DataManager.upgrades_changed.emit()
	return _ok()

# 🔹 Donne plusieurs exemplaires d'un pet dans un type donné, sans limite d'inventaire.
func debug_give_pets(pet_name: String, type_name: String, count: int) -> Dictionary:
	var type_info = GameConfig.get_type_by_name(type_name)
	if type_info.is_empty() or not GameConfig.PET_DEFINITIONS.has(pet_name):
		return _fail("unknown_pet")
	var pets = []
	for i in range(count):
		pets.append({"base_name": pet_name, "type": type_info})
	DataManager.add_pets_to_inventory(pets, true)
	return _ok()

# 🔹 Donne un exemplaire de chaque pet, en Classic ou dans tous les types.
func debug_give_all_pets(all_types: bool) -> Dictionary:
	var pets = []
	for pet_name in GameConfig.PET_DEFINITIONS:
		for type_info in GameConfig.PET_TYPES:
			if all_types or type_info.order == 0:
				pets.append({"base_name": pet_name, "type": type_info})
	DataManager.add_pets_to_inventory(pets, true)
	return _ok()

# 🔹 Découvre tous les pets de tous les œufs dans tous les types.
func debug_finish_index() -> Dictionary:
	for egg_def in GameConfig.EGG_DEFINITIONS:
		for pet_in_egg in egg_def.pets:
			for type_info in GameConfig.PET_TYPES:
				_discover_pet(pet_in_egg.name, egg_def.name, type_info)
	DataManager.index_status_changed.emit()
	return _ok()

# 🔹 Découvre en Classic assez d'espèces pour atteindre un pourcentage d'index.
func debug_force_index(percent: float) -> Dictionary:
	var target_count = int(ceil(percent / 100.0 * GameConfig.PET_DEFINITIONS.size()))
	var done = 0
	for pet_name in GameConfig.PET_DEFINITIONS:
		if done >= target_count:
			break
		_discover_pet(pet_name, GameConfig.get_source_egg_name(pet_name), GameConfig.PET_TYPES[0])
		done += 1
	DataManager.index_status_changed.emit()
	return _ok()

# 🔹 Remet à zéro les monnaies, les statistiques et les améliorations.
func debug_reset_stats() -> Dictionary:
	DataManager.coins = 0.0
	DataManager.gems = 0
	DataManager.time_played = 0
	DataManager.eggs_hatched = 0
	DataManager.total_coins_earned = 0.0
	DataManager.total_gems_earned = 0
	DataManager.debug_luck_override = 0.0
	DataManager.upgrade_levels = GameConfig.get_default_upgrade_levels()
	DataManager.recalculate_stats_from_upgrades()
	DataManager.sanitize_team()
	DataManager.gems_updated.emit(0)
	DataManager.upgrades_changed.emit()
	DataManager.equipped_pets_changed.emit()
	return _ok()

# 🔹 Remet à zéro les découvertes et les récompenses d'index.
func debug_reset_index() -> Dictionary:
	DataManager.discovered_pets.clear()
	DataManager.rarest_pet_ever_owned = {}
	DataManager.egg_index_status.clear()
	DataManager.ensure_default_structures()
	debug_reset_discovered_types()
	DataManager.recalculate_stats_from_upgrades()
	DataManager.index_status_changed.emit()
	return _ok()

# 🔹 Vide l'inventaire et l'équipe.
func debug_reset_inventory() -> Dictionary:
	DataManager.equipped_pets.clear()
	DataManager.player_inventory.clear()
	DataManager.next_pet_unique_id = 0
	DataManager.inventory_updated.emit()
	DataManager.total_pet_count_changed.emit(0)
	DataManager.equipped_pets_changed.emit()
	return _ok()

# 🔹 Oublie les types de pets découverts, sauf Classic.
func debug_reset_discovered_types() -> Dictionary:
	DataManager.discovered_pet_types.clear()
	DataManager.discovered_pet_types.append("Classic")
	return _ok()

# 🔹 Remet à zéro l'inventaire, l'index et les statistiques.
func debug_reset_all() -> Dictionary:
	debug_reset_inventory()
	debug_reset_index()
	debug_reset_stats()
	return _ok()

# 🔹 Simule et applique immédiatement un nombre d'heures de récompenses hors ligne.
func debug_force_offline(hours: int) -> Dictionary:
	var rewards = _simulate_offline_progress(hours * 3600)
	_apply_offline_gains(rewards)
	return _ok({"rewards": rewards})

# 🔹 Ajoute 1000 pets Classic répartis sur toutes les espèces et retourne la durée en millisecondes.
func debug_stress_test() -> Dictionary:
	var start_ms = Time.get_ticks_msec()
	var pet_names = GameConfig.PET_DEFINITIONS.keys()
	var pets = []
	for i in range(1000):
		pets.append({"base_name": pet_names[i % pet_names.size()], "type": GameConfig.PET_TYPES[0]})
	DataManager.add_pets_to_inventory(pets, true)
	return _ok({"elapsed_ms": Time.get_ticks_msec() - start_ms})

# 🔹 Sauvegarde immédiatement les options et la partie.
func debug_force_save() -> Dictionary:
	SaveManager.save_all()
	return _ok()
