# InventoryScreen.gd
extends PanelContainer

# --- Signaux ---
signal close_requested

# --- Constantes et Paramètres ---
const PET_SLOT_SCENE = preload("res://Scenes/PetSlot.tscn")
const CONFIRMATION_DIALOG_SCENE = preload("res://Scenes/ConfirmationDialog.tscn")
const RENDER_LAYER_PREVIEW = 3
const MAX_PETS = 1000 # Exemple, à synchroniser avec les données réelles si nécessaire

# --- Références aux Nœuds ---
@onready var details_panel: PanelContainer = %DetailsPanel
@onready var pet_grid: GridContainer = %PetGrid
@onready var pet_holder: Node3D = %PetHolder
@onready var pet_count_label: Label = %PetCountLabel
@onready var pet_name_label: Label = %PetNameLabel
@onready var rarity_label: Label = %RarityLabel
@onready var chance_label: Label = %ChanceLabel
@onready var coin_boost_label: Label = %CoinBoostLabel
@onready var luck_boost_label: Label = %LuckBoostLabel
@onready var speed_boost_label: Label = %SpeedBoostLabel
@onready var equip_button: Button = %EquipButton
@onready var fuse_button: Button = %FuseButton
@onready var fuse_all_button: Button = %FuseAllButton
@onready var sort_by_button: Button = %SortByButton

# --- État ---
var _grouped_inventory: Array[Dictionary] = []
var _selected_group_key: String = ""
var _sort_options = ["Rarity", "CoinBoost", "LuckBoost", "Count"]
var _current_sort_index = 0


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Connecte tous les signaux et initialise l'état de l'écran.
func _ready():
	details_panel.visible = false
	
	%CloseButton.pressed.connect(func(): close_requested.emit())
	%EquipButton.pressed.connect(_on_equip_pressed)
	%FuseButton.pressed.connect(_on_fuse_pressed)
	%FuseAllButton.pressed.connect(_on_fuse_all_pressed)
	%DeleteButton.pressed.connect(_on_delete_pressed)
	%SortByButton.pressed.connect(_on_sort_by_pressed)
	
	DataManager.inventory_updated.connect(redraw_inventory)
	DataManager.total_pet_count_changed.connect(_update_total_count)
	DataManager.equipped_pets_changed.connect(redraw_inventory)
	
	visibility_changed.connect(_on_visibility_changed)
	
	redraw_inventory()
	_update_total_count(DataManager.player_inventory.size())

# 🔹 Fait tourner le pet actuellement affiché dans le panneau de détails.
func _process(delta: float):
	if details_panel.visible and pet_holder.get_child_count() > 0:
		pet_holder.rotate_y(delta * 0.5)


# --- Gestion de l'Affichage Principal ---

# 🔹 Regroupe l'inventaire et redessine la grille de pets.
func redraw_inventory():
	var previously_selected_key = _selected_group_key
	
	_group_inventory()
	_sort_grouped_inventory()
	
	for child in pet_grid.get_children():
		child.queue_free()
	
	var selected_group_still_exists = false
	for pet_group in _grouped_inventory:
		if pet_group.key == previously_selected_key:
			selected_group_still_exists = true
 
		var slot = PET_SLOT_SCENE.instantiate()
		pet_grid.add_child(slot)
		slot.setup_grouped(pet_group)
		slot.pressed.connect(display_pet_details.bind(pet_group.key))
	
	if selected_group_still_exists:
		display_pet_details(previously_selected_key)
	else:
		_hide_details_panel()

# 🔹 Affiche les détails pour un groupe de pets sélectionné.
func display_pet_details(group_key: String):
	_selected_group_key = group_key
	var pet_group = _get_group_from_key(group_key)
	
	if pet_group.is_empty():
		_hide_details_panel()
		return
	
	details_panel.visible = true
	_update_details_panel(pet_group)
	_update_details_model(pet_group)

# --- Fonctions de Rappel (Signal Callbacks) ---

# 🔹 Gère l'action du bouton "Equip"/"Unequip".
func _on_equip_pressed():
	if _selected_group_key.is_empty(): return
	
	var pet_group = _get_group_from_key(_selected_group_key)
	if pet_group.is_empty(): return
	
	var pet_species = pet_group.data.base_name
	var pet_type_name = pet_group.data.type.name
	
	var equipped_instance = _find_equipped_instance_in_group(pet_species, pet_type_name)
	
	if equipped_instance:
		DataManager.unequip_pet(equipped_instance.unique_id)
	else:
		var instance_to_equip = _find_unequipped_instance_in_group(pet_species, pet_type_name)
		if instance_to_equip:
			DataManager.equip_pet(instance_to_equip.unique_id)
	
	# Rafraîchit l'état du bouton et potentiellement les styles des slots.
	redraw_inventory()

# 🔹 Gère l'action du bouton "Fuse".
func _on_fuse_pressed():
	if _selected_group_key.is_empty(): return
	var pet_group = _get_group_from_key(_selected_group_key)
	if pet_group.is_empty(): return
	
	DataManager.fuse_pets(pet_group.first_id)

# 🔹 Gère le clic sur le bouton "Fuse All".
func _on_fuse_all_pressed():
	fuse_all_button.disabled = true
	DataManager.fuse_all_pets()

# 🔹 Gère l'action du bouton "Delete".
func _on_delete_pressed():
	if _selected_group_key.is_empty(): return
	
	var dialog = CONFIRMATION_DIALOG_SCENE.instantiate()
	dialog.get_node("ConfirmationDialogLabel").text = "La suppression de groupe sera bientôt ajoutée !"
	add_child(dialog)
	dialog.popup_centered()

# 🔹 Met à jour le compteur du nombre total de pets.
func _update_total_count(new_count: int):
	pet_count_label.text = "%d / %d" % [new_count, MAX_PETS]

# 🔹 Réinitialise l'état de l'inventaire lorsque le panneau est fermé.
func _on_visibility_changed():
	if not visible:
		_hide_details_panel()

# 🔹 Change le critère de tri en passant au suivant dans la liste.
func _on_sort_by_pressed():
	_current_sort_index = (_current_sort_index +1) % _sort_options.size()
	redraw_inventory()


# --- Méthodes Internes de Mise à Jour de l'UI ---

# 🔹 Met à jour les labels du panneau de détails.
func _update_details_panel(pet_group: Dictionary):
	var pet_data = pet_group.data
	var base_pet_def = DataManager.PET_DEFINITIONS[pet_data.base_name]
	var rarity_def = DataManager.RARITIES[base_pet_def.rarity]
	
	pet_name_label.text = "%s (%s) [x%d]" % [pet_data.base_name, pet_data.type.name, pet_group.count]
	rarity_label.text = base_pet_def.rarity
	rarity_label.add_theme_color_override("font_color", rarity_def.color)
	chance_label.text = "(%s)" % _format_chance(DataManager.get_combined_chance(pet_data))
	coin_boost_label.text = "Coin Boost: x%s" % pet_data.stats.CoinBoost
	luck_boost_label.text = "Luck Boost: x%s" % pet_data.stats.LuckBoost
	speed_boost_label.text = "Speed Boost: x%s" % pet_data.stats.SpeedBoost
	
	_update_equip_button_state(pet_group)
	_update_fuse_button_state(pet_data, pet_group.count)

# 🔹 Met à jour l'état du bouton d'équipement.
func _update_equip_button_state(pet_group: Dictionary):
	var is_any_equipped = _find_equipped_instance_in_group(pet_group.data.base_name, pet_group.data.type.name) != null
	
	if is_any_equipped:
		equip_button.text = "Unequip"
		equip_button.disabled = false
	else:
		equip_button.text = "Equip"
		equip_button.disabled = DataManager.equipped_pets.size() >= DataManager.max_equipped_pets

# 🔹 Met à jour l'état du bouton de fusion.
func _update_fuse_button_state(pet_data: Dictionary, count_owned: int):
	var current_type_order = pet_data.type.order
	var required_amount = 10
	var next_type_exists = DataManager.PET_TYPES.any(func(t): return t.order == current_type_order + 1)
	
	fuse_button.visible = true
	if not next_type_exists:
		fuse_button.text = "Max Type"
		fuse_button.disabled = true
	else:
		fuse_button.text = "Fuse: %d/%d" % [count_owned, required_amount]
		fuse_button.disabled = count_owned < required_amount

# 🔹 Met à jour le modèle 3D affiché dans le panneau de détails.
func _update_details_model(pet_group: Dictionary):
	for child in pet_holder.get_children():
		child.queue_free()
	
	var base_pet_def = DataManager.PET_DEFINITIONS[pet_group.data.base_name]
	var pet_model = base_pet_def.model.instantiate()
	pet_holder.add_child(pet_model)
	
	_set_model_render_layer(pet_model, RENDER_LAYER_PREVIEW)
	_apply_preview_effect(pet_model, pet_group.data.type)

# 🔹 Cache le panneau de détails et réinitialise la sélection.
func _hide_details_panel():
	details_panel.visible = false
	_selected_group_key = ""

# --- Fonctions de Groupement et Utilitaires ---

# 🔹 Parcourt l'inventaire complet et le transforme en une liste de groupes.
func _group_inventory():
	_grouped_inventory.clear()
	var temp_groups = {}
	
	for pet_instance in DataManager.player_inventory:
		var key = "%s_%s" % [pet_instance.base_name, pet_instance.type.name]
		if not temp_groups.has(key):
			temp_groups[key] = {
				"key": key,
				"data": pet_instance,
				"rarity_order": DataManager.RARITIES[DataManager.PET_DEFINITIONS[pet_instance.base_name].rarity].order,
				"count": 0,
				"first_id": pet_instance.unique_id
			}
		temp_groups[key].count += 1
	
	for group in temp_groups.values():
		_grouped_inventory.append(group)

# 🔹 Récupère les données d'un groupe via sa clé unique.
func _get_group_from_key(key: String) -> Dictionary:
	for group in _grouped_inventory:
		if group.key == key:
			return group
	return {}

# 🔹 Trouve une instance équipée dans un groupe de pets.
func _find_equipped_instance_in_group(species: String, type_name: String) -> Dictionary:
	for pet_id in DataManager.equipped_pets:
		var pet_instance = DataManager.get_pet_by_id(pet_id)
		if not pet_instance.is_empty() and pet_instance.base_name == species and pet_instance.type.name == type_name:
			return pet_instance
	return {}

# 🔹 Trouve une instance non-équipée dans un groupe de pets.
func _find_unequipped_instance_in_group(species: String, type_name: String) -> Dictionary:
	for pet_instance in DataManager.player_inventory:
		if pet_instance.base_name == species and pet_instance.type.name == type_name:
			if not pet_instance.unique_id in DataManager.equipped_pets:
				return pet_instance
	return {}

# 🔹 Formate un pourcentage de chance en une chaîne de caractères lisible.
func _format_chance(chance_percent: float) -> String:
	if chance_percent <= 0.000001: return "1 in ∞"
	if chance_percent >= 1.0: return "%.2f%%" % chance_percent
	
	var denominator = 1.0 / (chance_percent / 100.0)
	
	if denominator >= 1_000_000_000_000.0: return "1 in %.1fT" % (denominator / 1_000_000_000_000.0)
	if denominator >= 1_000_000_000.0:   return "1 in %.1fB" % (denominator / 1_000_000_000.0)
	if denominator >= 1_000_000.0:       return "1 in %.1fM" % (denominator / 1_000_000.0)
	if denominator >= 1_000.0:           return "1 in %.1fK" % (denominator / 1_000.0)
	return "1 in %d" % round(denominator)

# 🔹 Applique un effet visuel (shader) au modèle de pet.
func _apply_preview_effect(pet_node: Node3D, type_info: Dictionary):
	var mesh_instance = _find_mesh_recursively(pet_node)
	if not mesh_instance: return
	
	mesh_instance.material_overlay = null
	
	if type_info.effect_type == "shader" and type_info.value is String and type_info.value.begins_with("res://"):
		var shader = load(type_info.value) as Shader
		if shader:
			var shader_material = ShaderMaterial.new()
			shader_material.shader = shader
			mesh_instance.material_overlay = shader_material

# 🔹 Applique une couche de rendu à tous les meshes d'un nœud et de ses enfants.
func _set_model_render_layer(node: Node, layer_number: int):
	var layer_mask = 1 << (layer_number - 1)
	if node is MeshInstance3D:
		node.layers = layer_mask
	for child in node.get_children():
		_set_model_render_layer(child, layer_number)

# 🔹 Trouve récursivement le premier nœud MeshInstance3D dans une hiérarchie.
func _find_mesh_recursively(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D: return node
	for child in node.get_children():
		var mesh = _find_mesh_recursively(child)
		if mesh: return mesh
	return null

# 🔹 Trie la liste _grouped_inventory selon le critère actuel.
func _sort_grouped_inventory():
	var sort_by = _sort_options[_current_sort_index]
	sort_by_button.text = "Trier par : %s" % sort_by.capitalize()
	
	_grouped_inventory.sort_custom(
		func(a, b):
			match sort_by:
				"Rarity":
					var chance_a = DataManager.get_combined_chance(a.data)
					var chance_b = DataManager.get_combined_chance(b.data)
					return chance_a < chance_b
				"CoinBoost":
					return a.data.stats.CoinBoost > b.data.stats.CoinBoost
				"LuckBoost":
					return a.data.stats.LuckBoost > b.data.stats.LuckBoost
				"Count":
					return a.count > b.count
			
			return false
	)
