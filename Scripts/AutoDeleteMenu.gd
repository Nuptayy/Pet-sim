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
	self.current_egg_name = egg_name
	%EggNameLabel.text = "Auto-Delete pour %s" % egg_name
	
	var rarity_list_container = %RarityList
	for child in rarity_list_container.get_children():
		child.free()
	rarity_groups.clear()
	
	var egg_filters = DataManager.auto_delete_filters.get(egg_name, {})
	var all_rarity_names = DataManager.RARITIES.keys
	all_rarity_names.sort_custom(func(a, b):
		return DataManager.RARITIES[a].order < DataManager.RARITIES[b].order
	)
	
	# Récupère la liste des types découverts depuis la source unique.
	var discovered_types_names = DataManager.get_discovered_types()
	var discovered_types_data = DataManager.PET_TYPES.filter(func(t): return t.name in discovered_types_names)
	
	for rarity_name in all_rarity_names:
		var current_type_filters = egg_filters.get(rarity_name, [])
		var group = RARITY_GROUP_SCENE.instantiate()
		
		# On passe la liste filtrée de types au groupe.
		group.setup(rarity_name, discovered_types_data, current_type_filters)
		
		group.filter_changed.connect(on_filter_changed)
		rarity_list_container.add_child(group)
		rarity_groups[rarity_name] = group
	
	show()


# --- Fonctions de Rappel (Signal Callbacks) ---

# 🔹 Met à jour et sauvegarde les filtres dans DataManager lorsqu'un changement est détecté.
func on_filter_changed():
	# S'assure que le dictionnaire pour cet œuf existe.
	if not DataManager.auto_delete_filters.has(current_egg_name):
		DataManager.auto_delete_filters[current_egg_name] = {}
	
	var egg_filters = DataManager.auto_delete_filters[current_egg_name]
	
	# Met à jour le dictionnaire de filtres en fonction des choix de l'utilisateur.
	for rarity_name in rarity_groups:
		var group = rarity_groups[rarity_name]
		var selected_types = group.get_selected_types()
		
		if selected_types.is_empty():
			# Si aucun type n'est coché pour une rareté, on retire la règle.
			egg_filters.erase(rarity_name)
		else:
			# Sinon, on met à jour la règle avec les types sélectionnés.
			egg_filters[rarity_name] = selected_types
	
	# Sauvegarde les changements et affiche un message de confirmation.
	SaveManager.save_game_data()
	print("Filtres pour %s sauvegardés: " % current_egg_name, egg_filters)
