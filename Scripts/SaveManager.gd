# SaveManager.gd
extends Node

# Le chemin vers notre fichier de sauvegarde.
const SAVE_PATH = "user://saves/settings.cfg"
var current_settings = {}

# 🔹 Appelé au démarrage pour charger toutes les données.
func load_all():
	load_options()
	# TODO: Plus tard, on ajoutera load_inventory(), etc.

# 🔹 Appelé à la fermeture pour sauvegarder toutes les données.
func save_all():
	save_options()
	# TODO: Plus tard, on ajoutera save_inventory(), etc.
	
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
