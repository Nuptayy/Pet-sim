# HatchingScreen.gd
extends PanelContainer

# --- Signaux ---
signal hatch_requested(egg_name, count)

# --- Constantes ---
const EGG_PANEL_SCENE = preload("res://Scenes/EggPanel.tscn")

# --- Références aux Nœuds ---
@onready var egg_list_container: VBoxContainer = %EggList
@onready var auto_delete_menu = %AutoDeleteMenu # Référence au sous-menu

# --- État ---
var selected_egg_name: String = ""
var egg_panels: Array[PanelContainer] = []


# --- Méthodes Publiques ---

# 🔹 Construit ou reconstruit la liste des panneaux d'œufs disponibles.
func setup(hatching_logic_node: Node):
	# Nettoie les anciens panneaux.
	for child in egg_list_container.get_children():
		child.queue_free()
	egg_panels.clear()

	# Crée un panneau pour chaque œuf défini dans le DataManager.
	for egg_def in DataManager.EGG_DEFINITIONS:
		var panel = EGG_PANEL_SCENE.instantiate()
		egg_list_container.add_child(panel)
		panel.setup(egg_def, hatching_logic_node.NumberOfEggMax)
		egg_panels.append(panel)
 
		# Connecte les signaux du panneau à ce gestionnaire.
		panel.hatch_requested.connect(_on_panel_hatch_requested)
		panel.select_requested.connect(_on_egg_selected)
		panel.auto_delete_requested.connect(auto_delete_menu.open_for_egg)

	# Sélectionne le premier œuf de la liste par défaut.
	if not egg_panels.is_empty():
		_on_egg_selected(egg_panels[0].egg_name)

# 🔹 Retourne le nom de l'œuf actuellement sélectionné.
func get_selected_egg_name() -> String:
	return selected_egg_name


# --- Fonctions de Rappel (Signal Callbacks) ---

# 🔹 Relaye la demande d'éclosion d'un panneau vers la scène principale.
func _on_panel_hatch_requested(egg_name: String, count: int):
	hatch_requested.emit(egg_name, count)

# 🔹 Met à jour l'état de sélection lorsqu'un œuf est choisi.
func _on_egg_selected(egg_name: String):
	selected_egg_name = egg_name
	for panel in egg_panels:
		panel.set_selected(panel.egg_name == selected_egg_name)
