# Backend.gd
extends Node

# --- Constantes ---
const LocalBackend = preload("res://Scripts/LocalBackend.gd")

# --- État Interne ---
var _implementation: Node


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Crée l'implémentation qui exécute réellement les actions du joueur.
func _ready():
	_implementation = LocalBackend.new()
	_implementation.name = "Implementation"
	add_child(_implementation)


# --- Session ---

# 🔹 Démarre la progression du joueur (gains passifs actifs).
func start_session():
	DataManager.progression_is_active = true

# 🔹 Met la progression du joueur en veille (menus).
func stop_session():
	DataManager.progression_is_active = false


# --- Actions du Joueur ---

# 🔹 Ouvre des œufs et retourne les pets tirés.
func hatch(egg_name: String, count: int) -> Dictionary:
	return _deliver(await _implementation.hatch(egg_name, count))

# 🔹 Équipe un pet.
func equip_pet(pet_id: int) -> Dictionary:
	return _deliver(await _implementation.equip_pet(pet_id))

# 🔹 Déséquipe un pet.
func unequip_pet(pet_id: int) -> Dictionary:
	return _deliver(await _implementation.unequip_pet(pet_id))

# 🔹 Déséquipe tous les pets de l'équipe.
func unequip_all_pets() -> Dictionary:
	return _deliver(await _implementation.unequip_all_pets())

# 🔹 Remplace l'équipe par les meilleurs pets pour une stat (CoinBoost, LuckBoost, GemBoost).
func equip_best_pets(stat_name: String) -> Dictionary:
	return _deliver(await _implementation.equip_best_pets(stat_name))

# 🔹 Fusionne 10 pets identiques à partir de l'un d'eux.
func fuse_pets(base_pet_id: int) -> Dictionary:
	return _deliver(await _implementation.fuse_pets(base_pet_id))

# 🔹 Fusionne en cascade tous les pets non équipés.
func fuse_all_pets() -> Dictionary:
	return _deliver(await _implementation.fuse_all_pets())

# 🔹 Supprime des pets de l'inventaire.
func delete_pets(pet_ids: Array) -> Dictionary:
	return _deliver(await _implementation.delete_pets(pet_ids))

# 🔹 Achète un niveau d'amélioration.
func buy_upgrade(upgrade_id: String) -> Dictionary:
	return _deliver(await _implementation.buy_upgrade(upgrade_id))

# 🔹 Réclame une récompense d'index.
func claim_index_reward(egg_name: String, type_name: String) -> Dictionary:
	return _deliver(await _implementation.claim_index_reward(egg_name, type_name))

# 🔹 Remplace les filtres d'auto-delete d'un œuf.
func set_auto_delete_filters(egg_name: String, filters: Dictionary) -> Dictionary:
	return _deliver(await _implementation.set_auto_delete_filters(egg_name, filters))

# 🔹 Définit l'œuf ouvert pendant que le jeu est fermé.
func set_offline_hatch_target(egg_name: String) -> Dictionary:
	return _deliver(await _implementation.set_offline_hatch_target(egg_name))

# 🔹 Récupère les récompenses hors ligne en attente.
func get_pending_offline_rewards() -> Dictionary:
	return _deliver(await _implementation.get_pending_offline_rewards())

# 🔹 Réclame les récompenses hors ligne en attente.
func claim_offline_rewards() -> Dictionary:
	return _deliver(await _implementation.claim_offline_rewards())


# --- Débogage ---

# 🔹 Indique si le menu debug et ses commandes de triche sont autorisés.
func is_debug_allowed() -> bool:
	return GameConfig.DEBUG_MENU_FOR_EVERYONE or OS.is_debug_build()

# 🔹 Exécute une commande de triche, si le debug est autorisé.
func debug(command: String, arguments: Array = []) -> Dictionary:
	var method_name = "debug_" + command
	if not is_debug_allowed() or not _implementation.has_method(method_name):
		return {"ok": false, "error": "debug_unavailable", "message": ""}
	return _deliver(await _implementation.callv(method_name, arguments))


# --- Méthodes Internes ---

# 🔹 Affiche le message d'un échec au joueur, puis retourne le résultat tel quel.
func _deliver(result: Dictionary) -> Dictionary:
	if not result.ok and not result.get("message", "").is_empty():
		DataManager.notify(result.message)
	return result
