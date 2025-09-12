# Main.gd
# 🔹 Ce script est le "chef d'orchestre". Il gère l'affichage des écrans et les inputs globaux.
extends Node

# Références directes aux nœuds de la scène.
@onready var hatching_screen = %HatchingScreen
@onready var inventory_screen = %InventoryScreen
@onready var hatching_logic = %HatchingLogic
@onready var hatching_animation_scene: Node3D = %HatchingAnimation

# 🔹 Initialisation du jeu.
func _ready():
	hatching_screen.setup(hatching_logic)

# Connecte les signaux.
	hatching_screen.hatch_requested.connect(hatching_logic.on_hatch_requested)
	inventory_screen.close_requested.connect(func(): set_game_state("hatching"))
	hatching_logic.animation_started.connect(func(): set_game_state("animating"))
	hatching_logic.animation_finished.connect(func(): set_game_state("hatching"))

# Transmet les références des nœuds 3D à la logique.
	hatching_logic.camera = hatching_animation_scene.get_node("Camera3D")
	hatching_logic.egg_grid_container = hatching_animation_scene.get_node("EggGridContainer")
	hatching_logic.viewport_container = get_viewport()

	set_game_state("hatching")

# 🔹 Gère les entrées du joueur.
func _input(event):
	if event.is_action_pressed("toggle_inventory"):
		if inventory_screen.visible:
			set_game_state("hatching")
		else:
			set_game_state("inventory")
		return

	if event.is_action_pressed("toggle_auto") and hatching_logic.AutoHatch:
		hatching_logic.AutoHatch = false
		print("🛑 Auto-Hatch désactivé par l'utilisateur.")
		return
	
	if hatching_screen.visible and not hatching_logic.IsHatching:
		var selected_egg = hatching_screen.get_selected_egg_name()
		if selected_egg.is_empty(): return
		
		if event.is_action_pressed("hatch_one"):
			hatching_logic.on_hatch_requested(selected_egg, 1)
		elif event.is_action_pressed("hatch_max"):
			hatching_logic.on_hatch_requested(selected_egg, hatching_logic.NumberOfEggMax)
		elif event.is_action_pressed("toggle_auto"):
			hatching_logic.on_hatch_requested(selected_egg, -1)

# 🔹 Fonction centrale pour changer l'état visuel du jeu.
func set_game_state(state_name: String):
	match state_name:
		"hatching":
			hatching_screen.visible = true
			inventory_screen.visible = false
			hatching_animation_scene.visible = false
			set_subviewport_rendering(hatching_screen, true)
			set_subviewport_rendering(inventory_screen, false)
		"inventory":
			hatching_screen.visible = false
			inventory_screen.visible = true
			hatching_animation_scene.visible = false
			set_subviewport_rendering(hatching_screen, false)
			set_subviewport_rendering(inventory_screen, true)
		"animating":
			hatching_screen.visible = false
			inventory_screen.visible = false
			hatching_animation_scene.visible = true
			set_subviewport_rendering(hatching_screen, false)
			set_subviewport_rendering(inventory_screen, false)

# 🔹 Active/désactive les SubViewports d'un nœud parent pour optimiser les performances.
func set_subviewport_rendering(parent_node: Node, is_enabled: bool):
	if not parent_node: return
	var viewports = parent_node.find_children("*", "SubViewport", true)
	for vp in viewports:
		if vp is SubViewport:
			vp.set_update_mode(SubViewport.UPDATE_ALWAYS if is_enabled else SubViewport.UPDATE_DISABLED)
