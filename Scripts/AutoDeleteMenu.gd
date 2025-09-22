# AutoDeleteMenu.gd
extends PanelContainer

const RARITY_GROUP_SCENE = preload("res://Scenes/RarityFilterGroup.tscn")
var current_egg_name: String
var rarity_groups: Dictionary = {}

func _ready():
	%CloseButton.pressed.connect(hide)

func open_for_egg(egg_name: String):
	self.current_egg_name = egg_name
	%EggNameLabel.text = "Auto-Delete pour %s" % egg_name
	var rarity_list_container = %RarityList
	for child in rarity_list_container.get_children():
		child.queue_free()
	rarity_groups.clear()
	var egg_filters = DataManager.auto_delete_filters.get(egg_name, {})
	var all_rarity_names = DataManager.rarities.keys()
	all_rarity_names.sort_custom(func(a, b):
		return DataManager.rarities[a]["order"] < DataManager.rarities[b]["order"]
	)
	for rarity_name in all_rarity_names:
		var current_type_filters = egg_filters.get(rarity_name, [])
		var group = RARITY_GROUP_SCENE.instantiate()
		group.setup(rarity_name, DataManager.pet_types, current_type_filters)
		group.filter_changed.connect(on_filter_changed)
		rarity_list_container.add_child(group)
		rarity_groups[rarity_name] = group
	
	show()

# 🔹 Appelé quand une case est cochée/décochée dans un des groupes.
func on_filter_changed():
	if not DataManager.auto_delete_filters.has(current_egg_name):
		DataManager.auto_delete_filters[current_egg_name] = {}
	
	var egg_filters = DataManager.auto_delete_filters[current_egg_name]
	for rarity_name in rarity_groups:
		var group = rarity_groups[rarity_name]
		var selected_types = group.get_selected_types()
		if selected_types.is_empty():
			if egg_filters.has(rarity_name):
				egg_filters.erase(rarity_name)
		else:
			egg_filters[rarity_name] = selected_types
	
	SaveManager.save_game_data()
	print("Filtres pour %s sauvegardés: " % current_egg_name, egg_filters)
