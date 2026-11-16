# AutoDeleteMenu.gd
extends PanelContainer

# --- Constantes ---
const RARITY_GROUP_SCENE = preload("res://Scenes/RarityFilterGroup.tscn")

# --- État ---
var current_egg_name: String
var rarity_groups: Dictionary = {}


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Connecte les signaux initiaux et prépare le nœud.
func _ready():
	%CloseButton.pressed.connect(hide)


# --- Méthodes Publiques ---

# 🔹 Ouvre et configure le menu pour un œuf spécifique.
func open_for_egg(egg_name: String):
	current_egg_name = egg_name
	%EggNameLabel.text = "Auto-Delete pour %s" % egg_name
	var rarity_list_container = %RarityList
	for child in rarity_list_container.get_children():
		child.free()
	rarity_groups.clear()
	var egg_filters = DataManager.auto_delete_filters.get(egg_name, {})
	var all_rarity_names: Array = GameConfig.RARITIES.keys()
	all_rarity_names.sort_custom(func(a, b): return GameConfig.RARITIES[a].order < GameConfig.RARITIES[b].order)
	var discovered_types_names = DataManager.get_discovered_types()
	var discovered_types_data = GameConfig.PET_TYPES.filter(func(t): return t.name in discovered_types_names)
	for rarity_name in all_rarity_names:
		var group = RARITY_GROUP_SCENE.instantiate()
		group.setup(rarity_name, discovered_types_data, egg_filters.get(rarity_name, []))
		group.filter_changed.connect(on_filter_changed)
		rarity_list_container.add_child(group)
		rarity_groups[rarity_name] = group
	show()


# --- Fonctions de Rappel (Signal Callbacks) ---

# 🔹 Envoie au backend les filtres choisis par le joueur pour l'œuf affiché.
func on_filter_changed():
	var filters = {}
	for rarity_name in rarity_groups:
		var selected_types = rarity_groups[rarity_name].get_selected_types()
		if not selected_types.is_empty():
			filters[rarity_name] = selected_types
	await Backend.set_auto_delete_filters(current_egg_name, filters)
