# Boot.gd
extends Node

# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Initialise le jeu en chargeant les données et en lançant le menu principal.
func _ready():
	SaveManager.load_all()
	get_tree().scene_changed.connect(on_scene_changed)
	get_tree().change_scene_to_file.call_deferred("res://Scenes/Main_menu.tscn")


# --- Fonctions de Rappel (Signal Callbacks) ---

# 🔹 Réapplique les paramètres graphiques à chaque changement de scène.
func on_scene_changed():
	# Recharge directement la valeur depuis les données déjà chargées par SaveManager.
	var fps_limit = SaveManager.current_settings.get("fps_limit", 0)
	Engine.max_fps = fps_limit
	
	# Applique la VSync car elle peut être réinitialisée par le moteur.
	var vsync_mode = SaveManager.current_settings.get("vsync_mode", DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_vsync_mode(vsync_mode)
	
	print("Paramètres moteur (FPS, VSync) réappliqués après changement de scène.")
