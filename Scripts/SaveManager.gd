# SaveManager.gd
extends Node

# --- Constantes ---
const SAVE_DIR = "user://saves"
const SETTINGS_PATH = "user://saves/settings.cfg"
const GAME_DATA_PATH = "user://saves/gamedata.cfg"
const GAME_DATA_TEMP_PATH = "user://saves/gamedata.cfg.new"
const GAME_DATA_BACKUP_PATH = "user://saves/gamedata.cfg.bak"
const GAME_DATA_CORRUPT_PATH = "user://saves/gamedata.corrupt.cfg"
const DEFERRED_SAVE_DELAY = 5.0

const DEFAULT_SETTINGS = {
	"display/resolution": Vector2i(1920, 1080),
	"display/fullscreen_mode": Window.MODE_WINDOWED,
	"display/vsync_mode": DisplayServer.VSYNC_ENABLED,
	"display/fps_limit": 0,
	"display/quality_index": 2,
	"gameplay/confirm_delete": true
}

# --- État Interne ---
var _settings: ConfigFile
var _save_pending: bool = false
var _deferred_save_timer: Timer


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Prépare le timer qui regroupe les sauvegardes demandées en rafale.
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_deferred_save_timer = Timer.new()
	_deferred_save_timer.wait_time = DEFERRED_SAVE_DELAY
	_deferred_save_timer.one_shot = true
	_deferred_save_timer.timeout.connect(_on_deferred_save_timeout)
	add_child(_deferred_save_timer)

# 🔹 Sauvegarde la partie quand l'application passe en arrière-plan (mobile).
func _notification(what: int):
	if what == NOTIFICATION_APPLICATION_PAUSED and DataManager.progression_is_active:
		save_game_data()


# --- Méthodes Publiques Générales ---

# 🔹 Charge les options puis les données de jeu.
func load_all():
	load_options()
	load_game_data()

# 🔹 Sauvegarde les options puis les données de jeu.
func save_all():
	save_options()
	save_game_data()

# 🔹 Demande une sauvegarde de la partie dans les prochaines secondes, sans en empiler plusieurs.
func request_save():
	_save_pending = true
	if _deferred_save_timer.is_stopped():
		_deferred_save_timer.start()


# --- Options ---

# 🔹 Charge les options depuis le disque et les applique au moteur.
func load_options():
	var config = _get_settings()
	Engine.max_fps = config.get_value("display", "fps_limit", DEFAULT_SETTINGS["display/fps_limit"])
	DisplayServer.window_set_vsync_mode(config.get_value("display", "vsync_mode", DEFAULT_SETTINGS["display/vsync_mode"]))
	if _is_mobile():
		return
	var window_mode = config.get_value("display", "fullscreen_mode", DEFAULT_SETTINGS["display/fullscreen_mode"])
	var resolution: Vector2i = config.get_value("display", "resolution", DEFAULT_SETTINGS["display/resolution"])
	var usable_size = DisplayServer.screen_get_usable_rect().size
	if window_mode == Window.MODE_WINDOWED and (resolution.x > usable_size.x or resolution.y > usable_size.y):
		get_window().mode = Window.MODE_MAXIMIZED
		return
	if window_mode == Window.MODE_WINDOWED:
		get_window().size = resolution
	get_window().mode = window_mode

# 🔹 Enregistre l'état actuel des options sur le disque.
func save_options():
	var config = _get_settings()
	config.set_value("display", "vsync_mode", DisplayServer.window_get_vsync_mode())
	config.set_value("display", "fps_limit", Engine.max_fps)
	if not _is_mobile() and get_window().mode == Window.MODE_WINDOWED:
		config.set_value("display", "resolution", get_window().size)
	_write_settings()

# 🔹 Retourne la valeur d'un paramètre ("section/clé") ou sa valeur par défaut.
func load_setting(key: String, default_value):
	return _get_settings().get_value(key.get_slice("/", 0), key.get_slice("/", 1), default_value)

# 🔹 Modifie un paramètre ("section/clé") et l'enregistre sur le disque.
func update_setting(key: String, value):
	_get_settings().set_value(key.get_slice("/", 0), key.get_slice("/", 1), value)
	_write_settings()

# 🔹 Retourne les paramètres en mémoire, en les lisant sur le disque au premier appel.
func _get_settings() -> ConfigFile:
	if _settings == null:
		_settings = ConfigFile.new()
		_settings.load(SETTINGS_PATH)
	return _settings

# 🔹 Écrit les paramètres en mémoire sur le disque.
func _write_settings():
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_get_settings().save(SETTINGS_PATH)

# 🔹 Indique si le jeu tourne sur un téléphone ou une tablette.
func _is_mobile() -> bool:
	return OS.has_feature("mobile")


# --- Données de Jeu ---

# 🔹 Sauvegarde la partie de façon sûre (fichier temporaire, backup, puis remplacement).
func save_game_data():
	_save_pending = false
	var config = ConfigFile.new()
	config.set_value("Session", "last_timestamp", Time.get_unix_time_from_system())
	_save_player_stats(config)
	_save_player_inventory(config)
	_save_player_team(config)
	_save_player_index(config)
	_save_player_upgrades(config)
	_save_auto_delete_filters(config)
	_save_index_status(config)
	_save_discovered_types(config)
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if config.save(GAME_DATA_TEMP_PATH) != OK:
		printerr("Sauvegarde impossible: écriture du fichier temporaire échouée.")
		return
	if FileAccess.file_exists(GAME_DATA_PATH):
		if FileAccess.file_exists(GAME_DATA_BACKUP_PATH):
			DirAccess.remove_absolute(GAME_DATA_BACKUP_PATH)
		DirAccess.rename_absolute(GAME_DATA_PATH, GAME_DATA_BACKUP_PATH)
	if DirAccess.rename_absolute(GAME_DATA_TEMP_PATH, GAME_DATA_PATH) != OK:
		printerr("Sauvegarde impossible: remplacement du fichier de sauvegarde échoué.")

# 🔹 Charge la partie depuis le fichier principal, ou depuis le backup s'il est illisible.
func load_game_data():
	var config = _load_valid_game_config()
	if config == null:
		return
	_load_player_stats(config)
	_load_player_upgrades(config)
	_load_player_inventory(config)
	_load_player_index(config)
	_load_auto_delete_filters(config)
	_load_index_status(config)
	_load_discovered_types(config)
	DataManager.ensure_default_structures()
	DataManager.recalculate_stats_from_upgrades()
	_load_player_team(config)
	DataManager.inventory_updated.emit()
	DataManager.total_pet_count_changed.emit(DataManager.player_inventory.size())
	DataManager.equipped_pets_changed.emit()

# 🔹 Retourne l'horodatage de la dernière sauvegarde, ou 0 s'il n'y en a pas.
func load_session_timestamp() -> int:
	var config = _load_valid_game_config()
	if config == null:
		return 0
	return int(config.get_value("Session", "last_timestamp", 0))

# 🔹 Retourne le premier fichier de sauvegarde lisible (principal puis backup), ou null.
func _load_valid_game_config() -> ConfigFile:
	var main_exists = FileAccess.file_exists(GAME_DATA_PATH)
	for path in [GAME_DATA_PATH, GAME_DATA_BACKUP_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var config = ConfigFile.new()
		if config.load(path) == OK and config.has_section("PlayerData"):
			return config
	if main_exists:
		printerr("Sauvegarde illisible: une copie est conservée dans ", GAME_DATA_CORRUPT_PATH)
		DirAccess.copy_absolute(GAME_DATA_PATH, GAME_DATA_CORRUPT_PATH)
	return null

# 🔹 Exécute la sauvegarde différée si elle est toujours en attente.
func _on_deferred_save_timeout():
	if _save_pending:
		save_game_data()


# --- Sections de Sauvegarde ---

# 🔹 Écrit les monnaies et statistiques du joueur.
func _save_player_stats(config: ConfigFile):
	config.set_value("PlayerData", "coins", DataManager.coins)
	config.set_value("PlayerData", "gems", DataManager.gems)
	config.set_value("PlayerData", "time_played", DataManager.time_played)
	config.set_value("PlayerData", "eggs_hatched", DataManager.eggs_hatched)
	config.set_value("PlayerData", "total_coins_earned", DataManager.total_coins_earned)
	config.set_value("PlayerData", "total_gems_earned", DataManager.total_gems_earned)
	config.set_value("PlayerData", "offline_hatch_target", DataManager.offline_hatch_target)
	if not DataManager.rarest_pet_ever_owned.is_empty():
		config.set_value("PlayerData", "rarest_pet_name", DataManager.rarest_pet_ever_owned.base_name)
		config.set_value("PlayerData", "rarest_pet_type", DataManager.rarest_pet_ever_owned.type.name)

# 🔹 Écrit la liste des pets possédés (identifiant, espèce, type).
func _save_player_inventory(config: ConfigFile):
	var pet_data_array = []
	for pet_instance in DataManager.player_inventory:
		pet_data_array.append({"uid": pet_instance.unique_id, "name": pet_instance.base_name, "type": pet_instance.type.name})
	config.set_value("Inventory", "pets", pet_data_array)

# 🔹 Écrit les identifiants des pets équipés.
func _save_player_team(config: ConfigFile):
	config.set_value("Team", "equipped_pets", DataManager.equipped_pets)

# 🔹 Écrit les pets découverts dans l'index.
func _save_player_index(config: ConfigFile):
	config.set_value("Index", "discovered_pets", DataManager.discovered_pets)

# 🔹 Écrit les niveaux des améliorations.
func _save_player_upgrades(config: ConfigFile):
	config.set_value("Upgrades", "levels", DataManager.upgrade_levels)

# 🔹 Écrit les filtres d'auto-delete.
func _save_auto_delete_filters(config: ConfigFile):
	config.set_value("AutoDelete", "filters", DataManager.auto_delete_filters)

# 🔹 Écrit l'état des récompenses d'index.
func _save_index_status(config: ConfigFile):
	config.set_value("Index", "status", DataManager.egg_index_status)

# 🔹 Écrit la liste des types de pets déjà découverts.
func _save_discovered_types(config: ConfigFile):
	config.set_value("Index", "discovered_types", DataManager.discovered_pet_types)


# --- Sections de Chargement ---

# 🔹 Lit les monnaies et statistiques du joueur.
func _load_player_stats(config: ConfigFile):
	DataManager.coins = max(0.0, float(config.get_value("PlayerData", "coins", 0.0)))
	DataManager.gems = maxi(0, int(config.get_value("PlayerData", "gems", 0)))
	DataManager.time_played = int(config.get_value("PlayerData", "time_played", 0))
	DataManager.eggs_hatched = int(config.get_value("PlayerData", "eggs_hatched", 0))
	DataManager.total_coins_earned = float(config.get_value("PlayerData", "total_coins_earned", 0.0))
	DataManager.total_gems_earned = int(config.get_value("PlayerData", "total_gems_earned", 0))
	var offline_target = str(config.get_value("PlayerData", "offline_hatch_target", ""))
	DataManager.offline_hatch_target = "" if GameConfig.get_egg_definition(offline_target).is_empty() else offline_target
	var rarest_name = str(config.get_value("PlayerData", "rarest_pet_name", ""))
	var rarest_type = GameConfig.get_type_by_name(str(config.get_value("PlayerData", "rarest_pet_type", "")))
	DataManager.rarest_pet_ever_owned = {}
	if GameConfig.PET_DEFINITIONS.has(rarest_name) and not rarest_type.is_empty():
		DataManager.rarest_pet_ever_owned = {"base_name": rarest_name, "type": rarest_type}

# 🔹 Lit les pets possédés en ignorant les entrées inconnues ou en double.
func _load_player_inventory(config: ConfigFile):
	var loaded_inventory: Array[Dictionary] = []
	var seen_ids = {}
	var max_id = -1
	var pet_data_array = config.get_value("Inventory", "pets", [])
	if typeof(pet_data_array) != TYPE_ARRAY:
		pet_data_array = []
	for pet_data in pet_data_array:
		if typeof(pet_data) != TYPE_DICTIONARY or not pet_data.has("uid") or not pet_data.has("name") or not pet_data.has("type"):
			continue
		var pet_id = int(pet_data.uid)
		var pet_name = str(pet_data.name)
		var pet_type_info = GameConfig.get_type_by_name(str(pet_data.type))
		if seen_ids.has(pet_id) or pet_type_info.is_empty() or not GameConfig.PET_DEFINITIONS.has(pet_name):
			continue
		seen_ids[pet_id] = true
		loaded_inventory.append({
			"unique_id": pet_id,
			"base_name": pet_name,
			"type": pet_type_info,
			"stats": GameConfig.calculate_final_stats(pet_name, pet_type_info)
		})
		max_id = maxi(max_id, pet_id)
	DataManager.player_inventory = loaded_inventory
	DataManager.next_pet_unique_id = max_id + 1

# 🔹 Lit l'équipe et retire les pets qui n'existent plus.
func _load_player_team(config: ConfigFile):
	var loaded_team = config.get_value("Team", "equipped_pets", [])
	var team: Array[int] = []
	if typeof(loaded_team) == TYPE_ARRAY or typeof(loaded_team) == TYPE_PACKED_INT64_ARRAY or typeof(loaded_team) == TYPE_PACKED_INT32_ARRAY:
		for pet_id in loaded_team:
			team.append(int(pet_id))
	DataManager.equipped_pets = team
	DataManager.sanitize_team()

# 🔹 Lit les pets découverts dans l'index.
func _load_player_index(config: ConfigFile):
	var loaded_data = config.get_value("Index", "discovered_pets", {})
	var discovered = {}
	if typeof(loaded_data) == TYPE_DICTIONARY:
		for pet_name in loaded_data:
			if GameConfig.PET_DEFINITIONS.has(pet_name):
				discovered[pet_name] = loaded_data[pet_name]
	DataManager.discovered_pets = discovered

# 🔹 Lit les niveaux des améliorations connues.
func _load_player_upgrades(config: ConfigFile):
	var levels = {}
	for upgrade_id in GameConfig.GEM_UPGRADES:
		levels[upgrade_id] = 0
	var loaded_levels = config.get_value("Upgrades", "levels", {})
	if typeof(loaded_levels) == TYPE_DICTIONARY:
		for upgrade_id in loaded_levels:
			if levels.has(upgrade_id):
				levels[upgrade_id] = maxi(0, int(loaded_levels[upgrade_id]))
	DataManager.upgrade_levels = levels

# 🔹 Lit les filtres d'auto-delete.
func _load_auto_delete_filters(config: ConfigFile):
	var loaded_filters = config.get_value("AutoDelete", "filters", {})
	DataManager.auto_delete_filters = loaded_filters if typeof(loaded_filters) == TYPE_DICTIONARY else {}

# 🔹 Lit l'état des récompenses d'index.
func _load_index_status(config: ConfigFile):
	var loaded_status = config.get_value("Index", "status", {})
	DataManager.egg_index_status = loaded_status if typeof(loaded_status) == TYPE_DICTIONARY else {}

# 🔹 Lit la liste des types de pets déjà découverts.
func _load_discovered_types(config: ConfigFile):
	var loaded_types = config.get_value("Index", "discovered_types", ["Classic"])
	var types: Array[String] = []
	if typeof(loaded_types) == TYPE_ARRAY or typeof(loaded_types) == TYPE_PACKED_STRING_ARRAY:
		for type_name in loaded_types:
			if not str(type_name) in types:
				types.append(str(type_name))
	if not "Classic" in types:
		types.append("Classic")
	DataManager.discovered_pet_types = types
