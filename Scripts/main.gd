# Main.gd
extends Node

# Références directes aux nœuds de la scène.
@onready var hatching_screen = %HatchingScreen
@onready var inventory_screen = %InventoryScreen
@onready var hatching_logic = %HatchingLogic
@onready var hatching_animation_scene: Node3D = %HatchingAnimation

func _ready():

# Connecte les signaux.
	hatching_screen.hatch_requested.connect(hatching_logic.on_hatch_requested)
	inventory_screen.close_requested.connect(func(): set_inventory_visible(false))
	hatching_logic.animation_started.connect(func(): set_animation_visible(true))
	hatching_logic.animation_finished.connect(func(): set_animation_visible(false))

# Transmet les références des nœuds 3D à la logique.
# Notez que nous ne passons plus le viewport_container.
	hatching_logic.camera = hatching_animation_scene.get_node("Camera3D")
	hatching_logic.egg_grid_container = hatching_animation_scene.get_node("EggGridContainer")
	hatching_logic.viewport_container = get_viewport() # On utilise le viewport principal.

# État initial du jeu.
	hatching_animation_scene.visible = false
	inventory_screen.visible = false
	hatching_screen.visible = true
	
func _input(event):
# 1. Gestion de l'inventaire.
	if event.is_action_pressed("toggle_inventory"):
		set_inventory_visible(!inventory_screen.visible)

# 2. Gestion de l'arrêt de l'auto-hatch (prioritaire).
	if event.is_action_pressed("toggle_auto") and hatching_logic.AutoHatch:
		hatching_logic.AutoHatch = false
		print("🛑 Auto-Hatch désactivé par l'utilisateur.")
		return

# 3. Gestion des actions d'éclosion (uniquement si aucune interface n'est par-dessus).
	if hatching_screen.visible and not inventory_screen.visible and not hatching_logic.IsHatching:
		var selected_egg = hatching_screen.get_selected_egg_name()
		if selected_egg.is_empty(): return

		if event.is_action_pressed("hatch_one"):
			hatching_logic.on_hatch_requested(selected_egg, 1)
		elif event.is_action_pressed("hatch_max"):
			hatching_logic.on_hatch_requested(selected_egg, hatching_logic.NumberOfEggMax)
		elif event.is_action_pressed("toggle_auto"):
			hatching_logic.on_hatch_requested(selected_egg, -1)

#🔹 Affiche ou cache le calque de l'animation 3D.
func set_animation_visible(is_visible: bool):
	hatching_animation_scene.visible = is_visible
# L'écran de sélection est caché pendant l'animation.
	hatching_screen.visible = !is_visible
# L'inventaire est toujours fermé pendant l'animation.
	if is_visible:
		inventory_screen.visible = false

#🔹 Affiche ou cache le calque de l'inventaire.
func set_inventory_visible(is_visible: bool):
	inventory_screen.visible = is_visible
# On ne peut pas voir l'écran de sélection en même temps que l'inventaire.
	hatching_screen.visible = !is_visible
