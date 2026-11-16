# HatchingScreen.gd
extends PanelContainer

# --- Signaux ---
signal hatch_requested(egg_name, count)

# --- Constantes ---
const PetVisuals = preload("res://Scripts/PetVisuals.gd")
const EGG_PANEL_SCENE = preload("res://Scenes/EggPanel.tscn")

# --- Références aux Nœuds ---
@onready var egg_list_container: VBoxContainer = %EggList
@onready var auto_delete_menu = %AutoDeleteMenu

# --- État ---
var selected_egg_name: String = ""
var egg_panels: Array[PanelContainer] = []


# --- Méthodes Publiques ---

# 🔹 Construit ou reconstruit la liste des panneaux d'œufs disponibles.
func setup(hatching_logic_node: Node):
	PetVisuals.clear_children(egg_list_container)
	egg_panels.clear()
	for egg_def in GameConfig.EGG_DEFINITIONS:
		var panel = EGG_PANEL_SCENE.instantiate()
		egg_list_container.add_child(panel)
		panel.setup(egg_def, hatching_logic_node.NumberOfEggMax)
		egg_panels.append(panel)
		panel.hatch_requested.connect(_on_panel_hatch_requested)
		panel.select_requested.connect(_on_egg_selected)
		panel.auto_delete_requested.connect(auto_delete_menu.open_for_egg)
		panel.offline_target_requested.connect(_on_offline_target_requested)
	_update_all_offline_targets()
	if egg_panels.is_empty():
		return
	var egg_to_select = egg_panels[0].egg_name
	for panel in egg_panels:
		if panel.egg_name == selected_egg_name:
			egg_to_select = selected_egg_name
	_on_egg_selected(egg_to_select)

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

# 🔹 Demande au backend de définir la cible de l'éclosion hors ligne.
func _on_offline_target_requested(egg_name: String):
	await Backend.set_offline_hatch_target(egg_name)
	_update_all_offline_targets()

# 🔹 Met à jour l'état visuel de tous les boutons de cible hors ligne.
func _update_all_offline_targets():
	for panel in egg_panels:
		panel.set_as_offline_target(panel.egg_name == DataManager.offline_hatch_target)
