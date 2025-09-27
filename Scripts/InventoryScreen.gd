# InventoryScreen.gd
extends PanelContainer

# --- Signaux ---
signal close_requested

# --- Constantes ---
const PET_SLOT_SCENE = preload("res://Scenes/PetSlot.tscn")
const CONFIRMATION_DIALOG_SCENE = preload("res://Scenes/ConfirmationDialog.tscn")
const RENDER_LAYER_PREVIEW = 3 # Couche de rendu pour les previews de l'UI
const MAX_PETS = 250 # TODO: Rendre cette valeur dynamique via DataManager

# --- Références aux Nœuds ---
@onready var details_panel: PanelContainer = %DetailsPanel
@onready var pet_grid: GridContainer = %PetGrid
@onready var pet_holder: Node3D = %PetHolder
@onready var pet_count_label: Label = %PetCountLabel
# Labels du panneau de détails
@onready var pet_name_label: Label = %PetNameLabel
@onready var rarity_label: Label = %RarityLabel
@onready var chance_label: Label = %ChanceLabel
@onready var coin_boost_label: Label = %CoinBoostLabel
@onready var luck_boost_label: Label = %LuckBoostLabel
@onready var speed_boost_label: Label = %SpeedBoostLabel
@onready var equip_button: Button = %EquipButton
@onready var fuse_button: Button = %FuseButton

# --- État ---
var current_selected_pet_id: int = -1


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Connecte tous les signaux et initialise l'état de l'écran.
func _ready():
	details_panel.visible = false
	
	# Connexions des boutons
	%CloseButton.pressed.connect(func(): close_requested.emit())
	%FuseButton.pressed.connect(_on_fuse_pressed)
	%EquipButton.pressed.connect(_on_equip_pressed)
	%DeleteButton.pressed.connect(_on_delete_pressed)
	
	# Connexions aux signaux globaux pour les mises à jour automatiques
	DataManager.inventory_updated.connect(redraw_inventory)
	DataManager.total_pet_count_changed.connect(_update_total_count)
	DataManager.equipped_pets_changed.connect(redraw_inventory)
	
	# Connexion pour gérer l'état à la fermeture
	visibility_changed.connect(_on_visibility_changed)
	
	# Initialise l'affichage
	redraw_inventory()
	_update_total_count(DataManager.player_inventory.size())

# 🔹 Fait tourner le pet actuellement affiché dans le panneau de détails.
func _process(delta: float):
	if details_panel.visible and pet_holder.get_child_count() > 0:
		pet_holder.rotate_y(delta * 0.5)


# --- Gestion de l'Affichage Principal ---

# 🔹 Redessine l'intégralité de la grille de pets.
func redraw_inventory():
	var previously_selected_id = current_selected_pet_id
	
	for child in pet_grid.get_children():
		child.queue_free()
	
	var selected_pet_still_exists = false
	for pet_instance in DataManager.player_inventory:
		if pet_instance.unique_id == previously_selected_id:
			selected_pet_still_exists = true
 
		var slot = PET_SLOT_SCENE.instantiate()
		pet_grid.add_child(slot)
		slot.setup(pet_instance)
		slot.pressed.connect(display_pet_details.bind(pet_instance.unique_id))
	
	if selected_pet_still_exists:
		display_pet_details(previously_selected_id)
	else:
		_hide_details_panel()

# 🔹 Affiche les détails pour un pet spécifique quand son slot est cliqué.
func display_pet_details(pet_id: int):
	current_selected_pet_id = pet_id
	var pet_data = DataManager.get_pet_by_id(pet_id)
	
	if pet_data.is_empty():
		_hide_details_panel()
		return
	
	details_panel.visible = true
	_update_details_panel(pet_data)
	_update_details_model(pet_data)


# --- Fonctions de Rappel (Signal Callbacks) ---

# 🔹 Gère l'action du bouton "Fuse".
func _on_fuse_pressed():
	if current_selected_pet_id != -1:
		DataManager.fuse_pets(current_selected_pet_id)

# 🔹 Gère l'action du bouton "Equip"/"Unequip".
func _on_equip_pressed():
	if current_selected_pet_id == -1: return
	
	if current_selected_pet_id in DataManager.equipped_pets:
		DataManager.unequip_pet(current_selected_pet_id)
	else:
		DataManager.equip_pet(current_selected_pet_id)
	
	# Met à jour l'état du bouton après l'action.
	_update_equip_button_state(current_selected_pet_id)

# 🔹 Gère l'action du bouton "Delete", en affichant une confirmation si nécessaire.
func _on_delete_pressed():
	if current_selected_pet_id == -1: return

	# Si l'option est désactivée, on supprime directement.
	var confirm_setting_path = "gameplay/confirm_delete" # Pourrait être une constante
	if not SaveManager.load_setting(confirm_setting_path, true):
		_delete_current_pet()
		return
 
	var dialog = CONFIRMATION_DIALOG_SCENE.instantiate()
	add_child(dialog)
	dialog.confirmed.connect(_delete_current_pet)
	dialog.popup_centered()

# 🔹 Met à jour le compteur du nombre total de pets.
func _update_total_count(new_count: int):
	pet_count_label.text = "%d / %d" % [new_count, MAX_PETS]

# 🔹 Réinitialise l'état de l'inventaire lorsque le panneau est fermé.
func _on_visibility_changed():
	if not visible:
		_hide_details_panel()


# --- Méthodes Internes de Mise à Jour de l'UI ---

# 🔹 Met à jour les labels du panneau de détails avec les informations d'un pet.
func _update_details_panel(pet_data: Dictionary):	
	var base_pet_def = DataManager.PET_DEFINITIONS[pet_data.base_name]
	var rarity_def = DataManager.RARITIES[base_pet_def.rarity]
	
	pet_name_label.text = "%s (%s)" % [pet_data.base_name, pet_data.type.name]
	rarity_label.text = base_pet_def.rarity
	rarity_label.add_theme_color_override("font_color", rarity_def.color)
	
	var combined_chance = DataManager.get_combined_chance(pet_data)
	chance_label.text = "(%s)" % _format_chance(combined_chance)
	
	coin_boost_label.text = "Coin Boost: x%s" % pet_data.stats.CoinBoost
	luck_boost_label.text = "Luck Boost: x%s" % pet_data.stats.LuckBoost
	speed_boost_label.text = "Speed Boost: x%s" % pet_data.stats.SpeedBoost
	
	_update_equip_button_state(pet_data.unique_id)
	_update_fuse_button_state(pet_data)

# 🔹 Met à jour l'état (texte, visibilité, état cliquable) du bouton de fusion.
func _update_fuse_button_state(pet_data: Dictionary):
	var pet_species = pet_data.base_name
	var current_type_order = pet_data.type.order
	var required_amount = 10

	# Vérifie s'il existe un type supérieur.
	var next_type_exists = false
	for pet_type in DataManager.PET_TYPES:
		if pet_type.order == current_type_order + 1:
			next_type_exists = true
			break
	
	if not next_type_exists:
		fuse_button.text = "Max Type"
		fuse_button.disabled = true
		fuse_button.visible = true
		return

	# Compte le nombre de pets identiques possédés.
	var count_owned = 0
	for p in DataManager.player_inventory:
		if p.base_name == pet_species and p.type.order == current_type_order:
			count_owned += 1
			
	fuse_button.text = "Fuse: %d/%d" % [count_owned, required_amount]
	fuse_button.disabled = count_owned < required_amount
	fuse_button.visible = true

# 🔹 Met à jour l'état (texte, activé/désactivé) du bouton d'équipement.
func _update_equip_button_state(pet_id: int):
	if pet_id in DataManager.equipped_pets:
		equip_button.text = "Unequip"
		equip_button.disabled = false
	else:
		equip_button.text = "Equip"
		equip_button.disabled = DataManager.equipped_pets.size() >= DataManager.max_equipped_pets

# 🔹 Met à jour le modèle 3D affiché dans le panneau de détails.
func _update_details_model(pet_data: Dictionary):
	# Nettoie le modèle précédent.
	for child in pet_holder.get_children():
		child.queue_free()
	
	# Instancie et configure le nouveau modèle.
	var base_pet_def = DataManager.PET_DEFINITIONS[pet_data.base_name]
	var pet_model = base_pet_def.model.instantiate()
	pet_holder.add_child(pet_model)
	
	_set_model_render_layer(pet_model, RENDER_LAYER_PREVIEW)
	_apply_preview_effect(pet_model, pet_data.type)

# 🔹 Exécute la suppression du pet actuellement sélectionné.
func _delete_current_pet():
	if current_selected_pet_id != -1:
		DataManager.remove_pet_by_id(current_selected_pet_id)
		# Le signal 'inventory_updated' se chargera de cacher le panneau via 'redraw_inventory'.

# 🔹 Cache le panneau de détails et réinitialise la sélection.
func _hide_details_panel():
	details_panel.visible = false
	current_selected_pet_id = -1


# --- Fonctions Utilitaires ---

# 🔹 Formate un pourcentage de chance en une chaîne de caractères lisible.
func _format_chance(chance_percent: float) -> String:
	if chance_percent <= 0.000001:
		return "1 in ∞"
	if chance_percent >= 1.0:
		return "%.2f%%" % chance_percent
	
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
	
	mesh_instance.material_overlay = null # Réinitialise
	
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
