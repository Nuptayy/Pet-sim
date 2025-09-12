# HatchingScreen.gd
extends PanelContainer

signal hatch_requested(egg_name, count)

const EGG_PANEL_SCENE = preload("res://Scenes/EggPanel.tscn")
var selected_egg_name = ""
var egg_panels = []

# Référence au VBoxContainer qui contient les panneaux d'œufs.
@onready var egg_list: VBoxContainer = %EggList

# 🔹 Au démarrage de cette scène, elle se construit elle-même.
func _ready():
	build_egg_list()

# 🔹 Construit la liste des panneaux d'œufs.
func build_egg_list():
	for child in egg_list.get_children():
		child.queue_free()
	egg_panels.clear()

	# Crée un panneau pour chaque œuf défini dans le DataManager.
	# Note : on suppose que HatchingLogic est accessible pour récupérer NumberOfEggMax.
	# Une meilleure pratique serait de mettre ce paramètre dans DataManager aussi.
	var number_of_egg_max = 12 # Valeur par défaut si la logique n'est pas trouvée.
	var hatching_logic_node = get_tree().get_first_node_in_group("hatching_logic") # Méthode robuste pour trouver la logique
	if hatching_logic_node:
		number_of_egg_max = hatching_logic_node.NumberOfEggMax

	for egg_def in DataManager.egg_definitions:
		var panel = EGG_PANEL_SCENE.instantiate()
		egg_list.add_child(panel)
		panel.setup(egg_def, number_of_egg_max)
		egg_panels.append(panel)
		
		# Connecte les signaux du panneau pour qu'ils soient gérés par cet écran.
		panel.hatch_requested.connect(_on_panel_hatch_requested)
		panel.select_requested.connect(_on_egg_selected)

	# Sélectionne le premier œuf de la liste par défaut au démarrage.
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
