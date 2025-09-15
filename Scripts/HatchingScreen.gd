# HatchingScreen.gd
# 🔹 Gère l'affichage de la liste des œufs disponibles et la sélection de l'œuf actif.
extends PanelContainer

signal hatch_requested(egg_name, count)

const EGG_PANEL_SCENE = preload("res://Scenes/EggPanel.tscn")

var selected_egg_name = ""
var egg_panels = []

@onready var egg_list: VBoxContainer = %EggList

# 🔹 Initialise l'écran en construisant la liste des œufs.
# Cette fonction est maintenant appelée par Main.gd pour assurer le bon ordre d'exécution.
func setup(hatching_logic_node: Node):
	for child in egg_list.get_children():
		child.queue_free()
	egg_panels.clear()

	# Crée un panneau pour chaque œuf défini dans le DataManager.
	for egg_def in DataManager.egg_definitions:
		var panel = EGG_PANEL_SCENE.instantiate()
		egg_list.add_child(panel)
		# On passe NumberOfEggMax au panneau pour qu'il puisse afficher le bon texte.
		panel.setup(egg_def, hatching_logic_node.NumberOfEggMax)
		egg_panels.append(panel)
		
		panel.hatch_requested.connect(_on_panel_hatch_requested)
		panel.select_requested.connect(_on_egg_selected)

	if not egg_panels.is_empty():
		_on_egg_selected(egg_panels[0].egg_name)

func _on_panel_hatch_requested(egg_name: String, count: int):
	hatch_requested.emit(egg_name, count)

func _on_egg_selected(egg_name: String):
	selected_egg_name = egg_name
	for panel in egg_panels:
		panel.set_selected(panel.egg_name == selected_egg_name)
		
func get_selected_egg_name() -> String:
	return selected_egg_name
