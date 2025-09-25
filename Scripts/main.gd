# Main.gd
extends Node

# --- Références aux Nœuds ---
@onready var hatching_screen: PanelContainer = %HatchingScreen
@onready var inventory_screen: PanelContainer = %InventoryScreen
@onready var index_screen: PanelContainer = %IndexScreen
@onready var pause_menu = %PauseMenu
@onready var hatching_logic: Node = %HatchingLogic
@onready var hatching_animation_scene: Node3D = %HatchingAnimation
# Références aux labels du HUD
@onready var coins_label: Label = %HatchingScreen.find_child("CoinsLabel", true)
@onready var gems_label: Label = %HatchingScreen.find_child("GemsLabel", true)


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Initialise la scène principale, connecte tous les systèmes et définit l'état de départ.
func _ready():
	# --- Bloc 1: Initialisation des Systèmes de Gameplay ---
	DataManager.progression_is_active = true
	
	# Configure HatchingLogic avec les bonnes valeurs (issues des améliorations)
	var base_hatch_max = hatching_logic.base_hatch_max
	var bonus_hatch_max = DataManager.get_hatch_max_bonus()
	hatching_logic.NumberOfEggMax = base_hatch_max + bonus_hatch_max
	
	# Initialise les références externes de HatchingLogic
	hatching_logic.camera = hatching_animation_scene.get_node("Camera3D")
	hatching_logic.egg_grid_container = hatching_animation_scene.get_node("EggGridContainer")
	hatching_logic.viewport_container = get_viewport()

	# --- Bloc 2: Connexion des Signaux de l'UI et du Gameplay ---
	# Signaux du menu pause
	pause_menu.continue_game.connect(toggle_pause)
	pause_menu.return_to_main_menu.connect(on_return_to_main_menu)
	
	# Signaux des écrans principaux
	hatching_screen.hatch_requested.connect(on_hatch_requested)
	inventory_screen.close_requested.connect(func(): set_game_state("hatching"))
	index_screen.close_requested.connect(index_screen.hide)
	
	# Signaux de l'animation d'éclosion
	hatching_logic.animation_started.connect(func(): set_game_state("animating"))
	hatching_logic.animation_finished.connect(func(): set_game_state("hatching"))
	
	# Signaux pour les mises à jour de données
	var options_menu = pause_menu.get_node("OptionsMenu")
	options_menu.graphic_settings_changed.connect(apply_quality_setting)
	DataManager.gems_updated.connect(_update_hud_gems)
	
	# --- Bloc 3: Configuration Finale de l'UI et État de Départ ---
	hatching_screen.get_node("%IndexButton").pressed.connect(index_screen.show)
	hatching_screen.setup(hatching_logic) # Doit être après la configuration de HatchingLogic
	
	# Initialise le HUD
	_update_hud_coins()
	_update_hud_gems(DataManager.gems)
	
	# Applique les paramètres graphiques
	apply_quality_setting(SaveManager.load_setting("display/quality_index", 2))
	
	# Définit l'état de jeu initial
	set_game_state("hatching")

# 🔹 Met à jour les éléments de l'UI qui changent à chaque frame, comme le compteur de pièces.
func _process(_delta: float):
	_update_hud_coins()

# 🔹 Gère les entrées clavier globales du joueur (pause, inventaire, raccourcis).
func _input(event: InputEvent):
	# Priorité 1: Gestion de la pause (touche Echap)
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		return
	
	# Ignore les autres inputs si le jeu est en pause.
	if get_tree().paused:
		return
	
	# Priorité 2: Gestion de l'inventaire (touche F)
	if event.is_action_pressed("toggle_inventory"):
		if inventory_screen.visible:
			set_game_state("hatching")
		else:
			set_game_state("inventory")
		return

	# Priorité 3: Arrêt de l'auto-hatch (touche T)
	if event.is_action_pressed("toggle_auto") and hatching_logic.auto_hatch_enabled:
		hatching_logic.auto_hatch_enabled = false # Demande l'arrêt
		print("🛑 Auto-Hatch désactivé par l'utilisateur.")
		return
	
	# Raccourcis pour l'éclosion, uniquement sur l'écran d'éclosion.
	if hatching_screen.visible and not hatching_logic.is_hatching:
		var selected_egg = hatching_screen.get_selected_egg_name()
		if selected_egg.is_empty(): return
 
		if event.is_action_pressed("hatch_one"):
			on_hatch_requested(selected_egg, 1)
		elif event.is_action_pressed("hatch_max"):
			on_hatch_requested(selected_egg, hatching_logic.NumberOfEggMax)
		elif event.is_action_pressed("toggle_auto"):
			on_hatch_requested(selected_egg, -1) # -1 est le code pour basculer l'auto-hatch

# 🔹 Gère les notifications du système d'exploitation, comme la fermeture de la fenêtre.
func _notification(what: int):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveManager.save_all()
		get_tree().quit()


# --- Gestion de l'État du Jeu et de la Pause ---

# 🔹 Change l'état visuel du jeu en affichant/cachant les écrans appropriés.
func set_game_state(state_name: String):
	var all_screens = [hatching_screen, inventory_screen, hatching_animation_scene]
	
	# Cache tous les écrans et désactive leurs interactions.
	for screen in all_screens:
		if is_instance_valid(screen):
			screen.visible = false
			if screen is Control:
				screen.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Active l'écran désiré et optimise le rendu des previews.
	match state_name:
		"hatching":
			hatching_screen.visible = true
			hatching_screen.mouse_filter = Control.MOUSE_FILTER_STOP
			set_subviewport_rendering(hatching_screen, true)
			set_subviewport_rendering(inventory_screen, false)
		"inventory":
			inventory_screen.visible = true
			inventory_screen.mouse_filter = Control.MOUSE_FILTER_STOP
			set_subviewport_rendering(hatching_screen, false)
			set_subviewport_rendering(inventory_screen, true)
		"animating":
			hatching_animation_scene.visible = true
			set_subviewport_rendering(hatching_screen, false)
			set_subviewport_rendering(inventory_screen, false)

# 🔹 Met en pause ou reprend le jeu et affiche/cache le menu de pause.
func toggle_pause():
	get_tree().paused = not get_tree().paused
	pause_menu.set_paused(get_tree().paused)

# 🔹 Gère le retour au menu principal depuis le menu pause.
func on_return_to_main_menu():
	get_tree().paused = false
	SaveManager.save_all()
	get_tree().change_scene_to_file("res://Scenes/Main_menu.tscn")


# --- Fonctions de Rappel (Signal Callbacks) ---

# 🔹 Reçoit et transmet les demandes d'éclosion au système de logique.
func on_hatch_requested(egg_name: String, count: int):
	if hatching_logic.is_hatching:
		return
	hatching_logic.on_hatch_requested(egg_name, count)


# --- Fonctions de Mise à Jour de l'UI et des Paramètres ---

# 🔹 Met à jour le label affichant le nombre de pièces du joueur.
func _update_hud_coins():
	if is_instance_valid(coins_label):
		coins_label.text = "Coins: %d" % DataManager.coins

# 🔹 Met à jour le label affichant le nombre de gemmes du joueur.
func _update_hud_gems(new_total: int):
	if is_instance_valid(gems_label):
		gems_label.text = "Gems: %d" % new_total

# 🔹 Applique les préréglages de qualité graphique au monde 3D.
func apply_quality_setting(index: int):
	var world_3d = get_viewport().world_3d
	if not world_3d: return
	
	var env: Environment = world_3d.environment
	if not env:
		print("AVERTISSEMENT: Aucun WorldEnvironment trouvé pour appliquer les paramètres de qualité.")
		return

	match index:
		0: # Basse
			env.ssao_enabled = false
			env.ssil_enabled = false
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		1: # Moyenne
			env.ssao_enabled = true
			env.ssil_enabled = false
			get_viewport().msaa_3d = Viewport.MSAA_2X
		2: # Haute
			env.ssao_enabled = true
			env.ssil_enabled = true
			get_viewport().msaa_3d = Viewport.MSAA_4X
	print("Paramètres de qualité appliqués (Index: %d)" % index)

# 🔹 Active ou désactive le rendu des SubViewports d'un nœud parent pour optimiser les performances.
func set_subviewport_rendering(parent_node: Node, is_enabled: bool):
	if not parent_node: return
	
	var update_mode = SubViewport.UPDATE_ALWAYS if is_enabled else SubViewport.UPDATE_DISABLED
	var viewports = parent_node.find_children("*", "SubViewport", true)
	for vp in viewports:
		if vp is SubViewport:
			vp.set_update_mode(update_mode)
