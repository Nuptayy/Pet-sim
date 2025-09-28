# SaveManager.gd
extends Node

# --- Constantes ---
const SETTINGS_PATH = "user://saves/settings.cfg"
const GAME_DATA_PATH = "user://saves/gamedata.cfg"

# --- État ---
# Dictionnaire des paramètres par défaut.
const DEFAULT_SETTINGS = {
	"display/resolution": Vector2i(1920, 1080),
	"display/fullscreen_mode": Window.MODE_WINDOWED,
	"display/vsync_mode": DisplayServer.VSYNC_ENABLED,
	"display/fps_limit": 0,
	"display/quality_index": 2, # 0:Basse, 1:Moyenne, 2:Haute
	"gameplay/confirm_delete": true
}


# ==============================================================================
# 1. ORCHESTRATION GLOBALE
# ==============================================================================

# 🔹 Charge toutes les données du jeu (options et progression) au démarrage.
func load_all():
	load_options()
	load_game_data()

# 🔹 Sauvegarde toutes les données du jeu (options et progression).
func save_all():
	save_options()
	save_game_data()


# ==============================================================================
# 2. GESTION DES OPTIONS DU JEU
# ==============================================================================

# 🔹 Charge les paramètres depuis le fichier de configuration et les applique.
func load_options():
	var config = ConfigFile.new()
	var error = config.load(SETTINGS_PATH)
	
	if error != OK:
		print("Fichier de paramètres non trouvé. Utilisation des valeurs par défaut.")
	
	get_window().size = config.get_value("display", "resolution", DEFAULT_SETTINGS["display/resolution"])
	get_window().mode = config.get_value("display", "fullscreen_mode", DEFAULT_SETTINGS["display/fullscreen_mode"])
	DisplayServer.window_set_vsync_mode(config.get_value("display", "vsync_mode", DEFAULT_SETTINGS["display/vsync_mode"]))
	Engine.max_fps = config.get_value("display", "fps_limit", DEFAULT_SETTINGS["display/fps_limit"])
	
	print("Options chargées.")

# 🔹 Sauvegarde tous les paramètres actuels dans le fichier de configuration.
func save_options():
	var config = ConfigFile.new()
	
	config.set_value("display", "resolution", get_window().size)
	config.set_value("display", "fullscreen_mode", get_window().mode)
	config.set_value("display", "vsync_mode", DisplayServer.window_get_vsync_mode())
	config.set_value("display", "fps_limit", Engine.max_fps)
	config.set_value("display", "quality_index", load_setting("display/quality_index", DEFAULT_SETTINGS["display/quality_index"]))
	config.set_value("gameplay", "confirm_delete", load_setting("gameplay/confirm_delete", DEFAULT_SETTINGS["gameplay/confirm_delete"]))
	
	DirAccess.make_dir_recursive_absolute("user://saves")
	config.save(SETTINGS_PATH)
	print("Options sauvegardées.")

# 🔹 Charge un paramètre spécifique depuis le fichier de configuration.
func load_setting(key: String, default_value):
	var section = key.get_slice("/", 0)
	var property = key.get_slice("/", 1)
	
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return default_value
	
	return config.get_value(section, property, default_value)

# 🔹 Met à jour un paramètre spécifique et sauvegarde immédiatement les options.
func update_setting(key: String, value):
	var section = key.get_slice("/", 0)
	var property = key.get_slice("/", 1)
	
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(section, property, value)
	
	DirAccess.make_dir_recursive_absolute("user://saves")
	config.save(SETTINGS_PATH)
	print("Paramètre '%s' mis à jour." % key)


# ==============================================================================
# 3. GESTION DES DONNÉES DE PROGRESSION
# ==============================================================================

# 🔹 Sauvegarde toutes les données de progression du joueur.
func save_game_data():
	var config = ConfigFile.new()
	
	_save_player_stats(config)
	_save_player_inventory(config)
	_save_player_team(config)
	_save_player_index(config)
	_save_player_upgrades(config)
	_save_auto_delete_filters(config)
	_save_index_status(config)
	_save_discovered_types(config)
	
	DirAccess.make_dir_recursive_absolute("user://saves")
	config.save(GAME_DATA_PATH)
	print("Données de jeu sauvegardées.")

# 🔹 Charge toutes les données de progression du joueur.
func load_game_data():
	var config = ConfigFile.new()
	if config.load(GAME_DATA_PATH) != OK:
		print("Aucun fichier de sauvegarde de jeu trouvé. Démarrage d'une nouvelle partie.")
		return
	
	_load_player_stats(config)
	_load_player_inventory(config)
	_load_player_team(config)
	_load_player_index(config)
	_load_player_upgrades(config)
	_load_auto_delete_filters(config)
	_load_index_status(config)
	_load_discovered_types(config)
	
	DataManager.recalculate_stats_from_upgrades()
	DataManager.inventory_updated.emit()
	DataManager.total_pet_count_changed.emit(DataManager.player_inventory.size())
	
	print("Données de jeu chargées.")


# --- Fonctions d'Aide pour la Sauvegarde/Chargement de la Progression ---

func _save_player_stats(config: ConfigFile):
	config.set_value("PlayerData", "coins", DataManager.coins)
	config.set_value("PlayerData", "gems", DataManager.gems)
	config.set_value("PlayerData", "time_played", DataManager.time_played)
	config.set_value("PlayerData", "eggs_hatched", DataManager.eggs_hatched)
	config.set_value("PlayerData", "total_coins_earned", DataManager.total_coins_earned)
	config.set_value("PlayerData", "total_gems_earned", DataManager.total_gems_earned)
	if not DataManager.rarest_pet_ever_owned.is_empty():
		config.set_value("PlayerData", "rarest_pet_name", DataManager.rarest_pet_ever_owned.base_name)
		config.set_value("PlayerData", "rarest_pet_type", DataManager.rarest_pet_ever_owned.type.name)

func _load_player_stats(config: ConfigFile):
	DataManager.coins = config.get_value("PlayerData", "coins", 0.0)
	DataManager.gems = config.get_value("PlayerData", "gems", 0)
	DataManager.time_played = config.get_value("PlayerData", "time_played", 0)
	DataManager.eggs_hatched = config.get_value("PlayerData", "eggs_hatched", 0)
	DataManager.total_coins_earned = config.get_value("PlayerData", "total_coins_earned", 0.0)
	DataManager.total_gems_earned = config.get_value("PlayerData", "total_gems_earned", 0)
	var rarest_name = config.get_value("PlayerData", "rarest_pet_name", "")
	var rarest_type_name = config.get_value("PlayerData", "rarest_pet_type", "")
	if not rarest_name.is_empty() and not rarest_type_name.is_empty():
		var type_info_array = DataManager.PET_TYPES.filter(func(t): return t.name == rarest_type_name)
		if not type_info_array.is_empty():
			DataManager.rarest_pet_ever_owned = {
				"base_name": rarest_name,
				"type": type_info_array.front()
				}

func _save_player_inventory(config: ConfigFile):
	# Sauvegarde l'inventaire sous forme d'un seul tableau de dictionnaires.
	var pet_data_array = []
	for pet_instance in DataManager.player_inventory:
		pet_data_array.append({
			"uid": pet_instance.unique_id,
			"name": pet_instance.base_name,
			"type": pet_instance.type.name
		})
	config.set_value("Inventory", "pets", pet_data_array)

func _load_player_inventory(config: ConfigFile):
	DataManager.player_inventory.clear()
	var pet_data_array = config.get_value("Inventory", "pets", [])
	var max_id = -1
	
	for pet_data in pet_data_array:
		# Trouve la définition complète du type à partir de son nom.
		var pet_type_info_array = DataManager.PET_TYPES.filter(func(t): return t.name == pet_data.type)
		if pet_type_info_array.is_empty(): continue
		var pet_type_info = pet_type_info_array.front()

		var pet_instance = {
			"unique_id": pet_data.uid,
			"base_name": pet_data.name,
			"type": pet_type_info,
			"stats": DataManager.calculate_final_stats(pet_data.name, pet_type_info)
		}
		DataManager.player_inventory.append(pet_instance)
		if pet_data.uid > max_id:
			max_id = pet_data.uid
	
	DataManager.next_pet_unique_id = max_id + 1

func _save_player_team(config: ConfigFile):
	config.set_value("Team", "equipped_pets", DataManager.equipped_pets)

func _load_player_team(config: ConfigFile):
	var loaded_team = config.get_value("Team", "equipped_pets", [])
	DataManager.equipped_pets.assign(loaded_team)

func _save_player_index(config: ConfigFile):
	config.set_value("Index", "discovered_pets", DataManager.discovered_pets)

func _load_player_index(config: ConfigFile):
	# Charge la donnée brute depuis le fichier.
	var loaded_data = config.get_value("Index", "discovered_pets", {})
	
	# --- GESTION DE LA COMPATIBILITÉ ---
	# Si la donnée chargée est un Array (ancien format), on l'ignore et on repart avec un dictionnaire vide.
	if typeof(loaded_data) == TYPE_ARRAY:
		print("Ancien format de sauvegarde pour 'discovered_pets' détecté. Réinitialisation de l'index.")
		DataManager.discovered_pets = {}
	# Si c'est bien un dictionnaire (nouveau format), on l'assigne.
	elif typeof(loaded_data) == TYPE_DICTIONARY:
		DataManager.discovered_pets = loaded_data
	else:
		# Sécurité supplémentaire au cas où la donnée est corrompue.
		DataManager.discovered_pets = {}

func _save_player_upgrades(config: ConfigFile):
	config.set_value("Upgrades", "levels", DataManager.upgrade_levels)

func _load_player_upgrades(config: ConfigFile):
	var default_levels = { "team_slots": 0, "hatch_max": 0, "permanent_luck": 0 }
	DataManager.upgrade_levels = config.get_value("Upgrades", "levels", default_levels)

func _save_auto_delete_filters(config: ConfigFile):
	config.set_value("AutoDelete", "filters", DataManager.auto_delete_filters)

func _load_auto_delete_filters(config: ConfigFile):
	DataManager.auto_delete_filters = config.get_value("AutoDelete", "filters", {})

func _save_index_status(config: ConfigFile):
	config.set_value("Index", "status", DataManager.egg_index_status)

func _load_index_status(config: ConfigFile):
	DataManager.egg_index_status = config.get_value("Index", "status", {})

func _save_discovered_types(config: ConfigFile):
	config.set_value("Index", "discovered_types", DataManager.discovered_pet_types)

func _load_discovered_types(config: ConfigFile):
	var loaded_types = config.get_value("Index", "discovered_types", ["Classic"])
	DataManager.discovered_pet_types.assign(loaded_types)
