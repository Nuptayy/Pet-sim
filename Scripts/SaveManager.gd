# SaveManager.gd
extends Node

# Le chemin vers notre fichier de sauvegarde.
const SAVE_PATH = "user://saves/settings.cfg"
const GAME_DATA_PATH = "user://saves/gamedata.cfg"
var current_settings = {}

# 🔹 Appelé au démarrage pour charger toutes les données.
func load_all():
	load_options()
	load_game_data()

# 🔹 Appelé à la fermeture pour sauvegarder toutes les données.
func save_all():
	save_options()
	save_game_data()
	
# --- OPTIONS ---

func save_options():
	var config = ConfigFile.new()
	config.set_value("display", "resolution", current_settings["resolution"])
	config.set_value("display", "fullscreen_mode", current_settings["fullscreen_mode"])
	config.set_value("display", "vsync_mode", current_settings["vsync_mode"])
	config.set_value("display", "fps_limit", current_settings["fps_limit"])
	config.set_value("display", "quality_index", current_settings["quality_index"])
	config.set_value("gameplay", "confirm_delete", current_settings["confirm_delete"])
	
	DirAccess.make_dir_recursive_absolute("user://saves")
	config.save(SAVE_PATH)
	print("Options sauvegardées.")

func load_options():
	var config = ConfigFile.new()
	if not FileAccess.file_exists(SAVE_PATH):
		current_settings = {
			"resolution": Vector2i(1920, 1080),
			"fullscreen_mode": Window.MODE_WINDOWED,
			"vsync_mode": DisplayServer.VSYNC_ENABLED,
			"fps_limit": 0,
			"quality_index": 2, # 0=Basse, 1=Moyenne, 2=Haute (par défaut)
			"confirm_delete": true
		}
	else:
		config.load(SAVE_PATH)
		current_settings = {
			"resolution": config.get_value("display", "resolution", Vector2i(1920, 1080)),
			"fullscreen_mode": config.get_value("display", "fullscreen_mode", Window.MODE_WINDOWED),
			"vsync_mode": config.get_value("display", "vsync_mode", DisplayServer.VSYNC_ENABLED),
			"fps_limit": config.get_value("display", "fps_limit", 0),
			"quality_index": config.get_value("display", "quality_index", 2),
			"confirm_delete": config.get_value("gameplay", "confirm_delete", true)
		}
	
	# Applique chaque paramètre chargé.
	get_window().size = current_settings["resolution"]
	get_window().mode = current_settings["fullscreen_mode"]
	DisplayServer.window_set_vsync_mode(current_settings["vsync_mode"])
	Engine.max_fps = current_settings["fps_limit"]
	print("Options chargées.")

# --- GESTION DES DONNÉES DE JEU ---

# 🔹 Sauvegarde toutes les données de progression du joueur.
func save_game_data():
	var config = ConfigFile.new()
	
	# 1. Sauvegarde des monnaies et des stats de base.
	config.set_value("PlayerData", "coins", DataManager.coins)
	config.set_value("PlayerData", "gems", DataManager.gems)
	config.set_value("PlayerData", "time_played", DataManager.time_played)
	config.set_value("PlayerData", "eggs_hatched", DataManager.eggs_hatched)
	config.set_value("PlayerData", "total_coins_earned", DataManager.total_coins_earned)
	config.set_value("PlayerData", "total_gems_earned", DataManager.total_gems_earned)
	config.set_value("AutoDelete", "filters", DataManager.auto_delete_filters)
	
	# 2. Sauvegarde de l'équipe.
	config.set_value("PlayerData", "equipped_pets", DataManager.equipped_pets)
	
	# 3. Sauvegarde de l'inventaire de pets.
	# On supprime l'ancienne section pour la recréer proprement.
	if config.has_section("Inventory"):
		config.erase_section("Inventory")
	
	# On sauvegarde chaque pet avec ses propriétés.
	for i in range(DataManager.player_inventory.size()):
		var pet_instance = DataManager.player_inventory[i]
		var section = "Pet_%d" % i
		config.set_value(section, "unique_id", pet_instance["unique_id"])
		config.set_value(section, "base_name", pet_instance["base_name"])
		config.set_value(section, "type_name", pet_instance["type"]["name"])
		
	# 4. Sauvegarde de l'index des pets découverts.
	# On convertit le dictionnaire en un tableau de noms, plus facile à sauvegarder.
	config.set_value("Index", "discovered_pets", DataManager.discovered_pets.keys())
	
	# 5. Sauvegarde le fichier sur le disque.
	DirAccess.make_dir_recursive_absolute("user://saves")
	config.save(GAME_DATA_PATH)
	print("Données de jeu sauvegardées.")

# 🔹 Charge toutes les données de progression du joueur.
func load_game_data():
	var config = ConfigFile.new()
	if not FileAccess.file_exists(GAME_DATA_PATH):
		print("Aucun fichier de sauvegarde de jeu trouvé. Démarrage d'une nouvelle partie.")
		return
		
	var err = config.load(GAME_DATA_PATH)
	if err != OK: return

	# 1. Charge les monnaies et les stats.
	DataManager.coins = config.get_value("PlayerData", "coins", 0.0)
	DataManager.gems = config.get_value("PlayerData", "gems", 0)
	DataManager.time_played = config.get_value("PlayerData", "time_played", 0)
	DataManager.eggs_hatched = config.get_value("PlayerData", "eggs_hatched", 0)
	DataManager.total_coins_earned = config.get_value("PlayerData", "total_coins_earned", 0.0)
	DataManager.total_gems_earned = config.get_value("PlayerData", "total_gems_earned", 0)
	DataManager.auto_delete_filters = config.get_value("AutoDelete", "filters", {})
	
	# 2. Chargement de l'équipe.
	DataManager.equipped_pets = config.get_value("PlayerData", "equipped_pets", [])
	
	# 3. Charge et reconstruit l'inventaire.
	DataManager.player_inventory.clear()
	var all_sections = config.get_sections()
	var pet_sections = []
	for section_name in all_sections:
		if section_name.begins_with("Pet_"):
			pet_sections.append(section_name)
	
	var max_id = -1
	for section in pet_sections:
		var pet_base_name = config.get_value(section, "base_name")
		var type_name = config.get_value(section, "type_name")
		var unique_id = config.get_value(section, "unique_id")
		var pet_type_info = {}
		for type_def in DataManager.pet_types:
			if type_def["name"] == type_name:
				pet_type_info = type_def
				break
		
		if not pet_type_info.is_empty():
			var pet_instance = {
				"unique_id": unique_id,
				"base_name": pet_base_name,
				"type": pet_type_info,
				"stats": DataManager.calculate_final_stats(pet_base_name, pet_type_info)
			}
			DataManager.player_inventory.append(pet_instance)
			if unique_id > max_id:
				max_id = unique_id
	
	DataManager.next_pet_unique_id = max_id + 1
	
	# 4. Charge l'index.
	var discovered_array = config.get_value("Index", "discovered_pets", [])
	DataManager.discovered_pets.clear()
	for pet_name in discovered_array:
		DataManager.discovered_pets[pet_name] = true
		
	print("Données de jeu chargées.")
	DataManager.inventory_updated.emit()
	DataManager.total_pet_count_changed.emit(DataManager.player_inventory.size())
