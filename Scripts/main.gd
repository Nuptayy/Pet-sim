# Main.gd
extends Node

# On utilise % pour des références sûres et faciles.
@onready var hatching_screen = %HatchingScreen
@onready var inventory_screen = %InventoryScreen
@onready var hatching_logic = %HatchingLogic
@onready var hatching_animation_scene: Node3D = %HatchingAnimation

# 🔹 Initialisation du jeu.
func _ready():
	hatching_screen.setup(hatching_logic)
	
	# Connecte les signaux.
	hatching_screen.hatch_requested.connect(on_hatch_requested)
	inventory_screen.close_requested.connect(func(): set_game_state("hatching"))
	hatching_logic.animation_started.connect(func(): set_game_state("animating"))
	hatching_logic.animation_finished.connect(func(): set_game_state("hatching"))

	# Transmet les références des nœuds 3D à la logique.
	hatching_logic.camera = hatching_animation_scene.get_node("Camera3D")
	hatching_logic.egg_grid_container = hatching_animation_scene.get_node("EggGridContainer")
	hatching_logic.viewport_container = get_viewport()

	# Configure l'état initial du jeu.
	set_game_state("hatching")

# 🔹 Gère les entrées du joueur.
func _input(event):
	# 1. Gestion de l'inventaire (Touche F). C'est la priorité n°1.
	if event.is_action_pressed("toggle_inventory"):
		if inventory_screen.visible:
			set_game_state("hatching")
		else:
			set_game_state("inventory")
		return

	# 2. Gestion de l'arrêt de l'auto-hatch (Touche T, priorité n°2).
	if event.is_action_pressed("toggle_auto") and hatching_logic.AutoHatch:
		hatching_logic.AutoHatch = false
		print("🛑 Auto-Hatch désactivé par l'utilisateur.")
		return
	
	# 3. Gestion des autres actions (E, R, T pour démarrer)
	if hatching_screen.visible and not hatching_logic.IsHatching:
		var selected_egg = hatching_screen.get_selected_egg_name()
		if selected_egg.is_empty(): return
		
		# Les touches appellent la même fonction centrale que les boutons de l'UI.
		if event.is_action_pressed("hatch_one"):
			on_hatch_requested(selected_egg, 1)
		elif event.is_action_pressed("hatch_max"):
			on_hatch_requested(selected_egg, hatching_logic.NumberOfEggMax)
		elif event.is_action_pressed("toggle_auto"):
			on_hatch_requested(selected_egg, -1)

# 🔹 Fonction centrale qui reçoit TOUTES les demandes d'éclosion.
func on_hatch_requested(egg_name: String, count: int):
	if hatching_logic.IsHatching:
		return
	hatching_logic.on_hatch_requested(egg_name, count)
			
# 🔹 Fonction centrale pour changer l'état visuel du jeu.
func set_game_state(state_name: String):
	# On récupère tous les écrans principaux.
	var all_screens = [hatching_screen, inventory_screen, hatching_animation_scene]
	
	# On désactive d'abord tous les écrans pour éviter les conflits.
	for screen in all_screens:
		if is_instance_valid(screen):
			screen.visible = false
			# On dit aux écrans d'interface d'ignorer complètement la souris quand ils sont cachés.
			if screen is Control:
				screen.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Ensuite, on active uniquement l'écran désiré.
	match state_name:
		"hatching":
			hatching_screen.visible = true
			hatching_screen.mouse_filter = Control.MOUSE_FILTER_STOP # Redevient interactif
			set_subviewport_rendering(hatching_screen, true)
			set_subviewport_rendering(inventory_screen, false)
		"inventory":
			inventory_screen.visible = true
			inventory_screen.mouse_filter = Control.MOUSE_FILTER_STOP # Redevient interactif
			set_subviewport_rendering(hatching_screen, false)
			set_subviewport_rendering(inventory_screen, true)
		"animating":
			hatching_animation_scene.visible = true
			# Les écrans UI sont déjà cachés et ignorent la souris.

# 🔹 Active/désactive les SubViewports d'un nœud parent pour optimiser.
func set_subviewport_rendering(parent_node: Node, is_enabled: bool):
	if not parent_node: return
	var viewports = parent_node.find_children("*", "SubViewport", true)
	for vp in viewports:
		if vp is SubViewport:
			vp.set_update_mode(SubViewport.UPDATE_ALWAYS if is_enabled else SubViewport.UPDATE_DISABLED)
