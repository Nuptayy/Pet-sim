# InventoryScreen.gd
extends PanelContainer

# --- Signaux ---
signal close_requested

# --- Constantes ---
const PetVisuals = preload("res://Scripts/PetVisuals.gd")
const NumberFormat = preload("res://Scripts/NumberFormat.gd")
const PET_SLOT_SCENE = preload("res://Scenes/PetSlot.tscn")
const TEAM_SLOT_SCENE = preload("res://Scenes/TeamSlot.tscn")
const TEAM_SLOT_SIZE = Vector2(138, 138)
const PET_SLOT_WIDTH = 128
const PET_SLOT_H_SEP = 4
const NO_PET_ID = -1
const MAX_SLIDER_TICKS = 21
const EQUIP_BEST_STATS = ["CoinBoost", "LuckBoost"]
const DEFAULT_EQUIP_BEST_STAT = "CoinBoost"

# --- Références aux Nœuds ---
@onready var details_panel: PanelContainer = %DetailsPanel
@onready var pet_grid: GridContainer = %PetGrid
@onready var pet_grid_scroll: ScrollContainer = $MarginContainer/VBoxContainer/MainContent/PetGridScrollContainer
@onready var team_bar_container: FlowContainer = %TeamBarContainer
@onready var pet_holder: Node3D = %PetHolder
@onready var pet_count_label: Label = %PetCountLabel
@onready var pet_name_label: Label = %PetNameLabel
@onready var rarity_label: Label = %RarityLabel
@onready var chance_label: Label = %ChanceLabel
@onready var coin_boost_label: Label = %CoinBoostLabel
@onready var luck_boost_label: Label = %LuckBoostLabel
@onready var gem_boost_label: Label = %SpeedBoostLabel
@onready var equip_button: Button = %EquipButton
@onready var fuse_button: Button = %FuseButton
@onready var delete_button: Button = %DeleteButton
@onready var fuse_all_button: Button = %FuseAllButton
@onready var sort_by_button: Button = %SortByButton
@onready var search_bar: LineEdit = %SearchBar

# --- Nœuds Créés par le Script ---
var unequip_all_button: Button
var equip_best_button: Button
var mass_delete_button: Button
var mass_delete_bar: HBoxContainer
var mass_selection_label: Label
var mass_confirm_button: Button
var quantity_box: VBoxContainer
var quantity_edit: LineEdit
var quantity_max_label: Label
var quantity_slider: HSlider

# --- État ---
var _grouped_inventory: Array[Dictionary] = []
var _selected_group_key: String = ""
var _selected_equipped_id: int = NO_PET_ID
var _displayed_model_key: String = ""
var _sort_options = ["Rarity", "CoinBoost", "LuckBoost", "Count"]
var _current_sort_index = 0
var _search_text: String = ""
var _redraw_queued: bool = false
var _is_dirty: bool = true
var _slots_by_key: Dictionary = {}
var _mass_delete_mode: bool = false
var _mass_selection: Dictionary = {}
var _mass_active_key: String = ""


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Connecte les boutons et les signaux de données, puis prépare le premier affichage.
func _ready():
	details_panel.visible = false
	_build_header_buttons()
	_build_mass_delete_bar()
	team_bar_container.alignment = FlowContainer.ALIGNMENT_CENTER
	pet_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	%CloseButton.pressed.connect(func(): close_requested.emit())
	equip_button.pressed.connect(_on_equip_pressed)
	fuse_button.pressed.connect(_on_fuse_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	fuse_all_button.pressed.connect(_on_fuse_all_pressed)
	sort_by_button.pressed.connect(_on_sort_by_pressed)
	search_bar.text_changed.connect(_on_search_changed)
	DataManager.inventory_updated.connect(request_redraw)
	DataManager.equipped_pets_changed.connect(request_redraw)
	DataManager.upgrades_changed.connect(_on_upgrades_changed)
	DataManager.total_pet_count_changed.connect(_update_total_count)
	visibility_changed.connect(_on_visibility_changed)
	pet_grid_scroll.resized.connect(_update_grid_columns)
	_update_grid_columns.call_deferred()
	_update_total_count(DataManager.player_inventory.size())
	request_redraw()

# 🔹 Fait tourner le modèle 3D du pet affiché dans le panneau de détails.
func _process(delta: float):
	if details_panel.visible and pet_holder.get_child_count() > 0:
		pet_holder.rotate_y(delta * 0.5)


# --- Grille Adaptative ---

# 🔹 Recalcule le nombre de colonnes selon la largeur disponible.
func _update_grid_columns():
	var available_width = pet_grid_scroll.size.x
	if available_width <= 0:
		return
	pet_grid.columns = max(1, int(available_width / (PET_SLOT_WIDTH + PET_SLOT_H_SEP)))


# --- Affichage Principal ---

# 🔹 Demande un redessin, regroupé en fin de frame et reporté si l'écran est caché.
func request_redraw():
	if not is_visible_in_tree():
		_is_dirty = true
		return
	if _redraw_queued:
		return
	_redraw_queued = true
	redraw_inventory.call_deferred()

# 🔹 Reconstruit la grille des pets et la barre d'équipe, puis restaure la sélection.
func redraw_inventory():
	_redraw_queued = false
	if not is_visible_in_tree():
		_is_dirty = true
		return
	_is_dirty = false
	_group_inventory()
	_sort_grouped_inventory()
	PetVisuals.clear_children(pet_grid)
	_slots_by_key.clear()
	for pet_group in _get_filtered_groups():
		var slot = PET_SLOT_SCENE.instantiate()
		pet_grid.add_child(slot)
		slot.setup_grouped(pet_group)
		slot.pressed.connect(_on_slot_pressed.bind(pet_group.key))
		_slots_by_key[pet_group.key] = slot
	_redraw_team_bar()
	_sync_mass_selection()
	_restore_selection()

# 🔹 Affiche les détails d'un groupe de pets non équipés.
func display_pet_details(group_key: String):
	var pet_group = _get_group_from_key(group_key)
	if pet_group.is_empty():
		_hide_details_panel()
		return
	_selected_group_key = group_key
	_selected_equipped_id = NO_PET_ID
	_show_details(pet_group.data, pet_group.count, false)

# 🔹 Affiche les détails d'un pet équipé (clic sur un slot d'équipe).
func display_equipped_pet(pet_instance: Dictionary):
	if _mass_delete_mode:
		return
	if pet_instance.is_empty() or not pet_instance.unique_id in DataManager.equipped_pets:
		_hide_details_panel()
		return
	_selected_equipped_id = pet_instance.unique_id
	_selected_group_key = ""
	_show_details(pet_instance, 1, true)

# 🔹 Réaffiche la sélection précédente si elle existe encore, sinon ferme les détails.
func _restore_selection():
	if _selected_equipped_id != NO_PET_ID and _selected_equipped_id in DataManager.equipped_pets:
		display_equipped_pet(DataManager.get_pet_by_id(_selected_equipped_id))
	elif not _get_group_from_key(_selected_group_key).is_empty():
		display_pet_details(_selected_group_key)
	else:
		_hide_details_panel()


# --- Fonctions de Rappel (Signal Callbacks) ---

# 🔹 Ouvre les détails d'un groupe, ou le coche pour la suppression en mode Mass Delete.
func _on_slot_pressed(group_key: String):
	if _mass_delete_mode:
		_toggle_mass_selection(group_key)
	else:
		display_pet_details(group_key)

# 🔹 Déséquipe toute l'équipe d'un coup.
func _on_unequip_all_pressed():
	_selected_equipped_id = NO_PET_ID
	await Backend.unequip_all_pets()

# 🔹 Remplace l'équipe par les meilleurs pets selon le tri en cours (Coin Boost par défaut).
func _on_equip_best_pressed():
	var stat_name = _sort_options[_current_sort_index]
	if not stat_name in EQUIP_BEST_STATS:
		stat_name = DEFAULT_EQUIP_BEST_STAT
	_selected_equipped_id = NO_PET_ID
	equip_best_button.disabled = true
	await Backend.equip_best_pets(stat_name)
	equip_best_button.disabled = false

# 🔹 Équipe un pet du groupe sélectionné, ou déséquipe le pet d'équipe sélectionné.
func _on_equip_pressed():
	if _selected_equipped_id != NO_PET_ID:
		var pet_id = _selected_equipped_id
		var pet_instance = DataManager.get_pet_by_id(pet_id)
		_selected_equipped_id = NO_PET_ID
		if not pet_instance.is_empty():
			_selected_group_key = _make_group_key(pet_instance)
		await Backend.unequip_pet(pet_id)
		return
	var pet_group = _get_group_from_key(_selected_group_key)
	if not pet_group.is_empty():
		await Backend.equip_pet(pet_group.first_id)

# 🔹 Fusionne 10 pets du groupe sélectionné.
func _on_fuse_pressed():
	var pet_group = _get_group_from_key(_selected_group_key)
	if not pet_group.is_empty():
		await Backend.fuse_pets(pet_group.first_id)

# 🔹 Lance la fusion en cascade de tout l'inventaire.
func _on_fuse_all_pressed():
	fuse_all_button.disabled = true
	await Backend.fuse_all_pets()
	fuse_all_button.disabled = false

# 🔹 Supprime un seul exemplaire du groupe sélectionné, après confirmation si l'option est active.
func _on_delete_pressed():
	var pet_group = _get_group_from_key(_selected_group_key)
	if pet_group.is_empty():
		return
	var question = "Supprimer 1x %s %s ?" % [pet_group.data.type.name, pet_group.data.base_name]
	_ask_delete_confirmation(question, _delete_one.bind(_selected_group_key))

# 🔹 Supprime la sélection du mode Mass Delete, après confirmation si l'option est active.
func _on_mass_delete_confirm_pressed():
	var pet_count = _get_mass_selection_total()
	if pet_count == 0:
		return
	_ask_delete_confirmation("Supprimer %d pet(s) ?" % pet_count, _delete_mass_selection)

# 🔹 Applique la quantité choisie au slider au groupe actif.
func _on_quantity_slider_changed(new_value: float):
	_set_mass_quantity(_mass_active_key, int(new_value))

# 🔹 Valide la quantité saisie au clavier en quittant le champ.
func _on_quantity_typed(_new_text: String):
	quantity_edit.release_focus()

# 🔹 Applique la quantité saisie au clavier au groupe actif.
func _on_quantity_focus_exited():
	_set_mass_quantity(_mass_active_key, quantity_edit.text.to_int())

# 🔹 Met à jour le compteur de pets affiché dans l'en-tête.
func _update_total_count(new_count: int):
	pet_count_label.text = "%d / %d" % [new_count, DataManager.get_max_inventory_size()]

# 🔹 Rafraîchit le compteur et l'équipe quand une amélioration change leur taille.
func _on_upgrades_changed():
	_update_total_count(DataManager.player_inventory.size())
	request_redraw()

# 🔹 Redessine l'écran s'il a changé pendant qu'il était caché, ou ferme les détails en sortant.
func _on_visibility_changed():
	if not is_visible_in_tree():
		_set_mass_delete_mode(false)
		_hide_details_panel()
	elif _is_dirty:
		request_redraw()

# 🔹 Passe au critère de tri suivant.
func _on_sort_by_pressed():
	_current_sort_index = (_current_sort_index + 1) % _sort_options.size()
	request_redraw()

# 🔹 Met à jour le filtre de recherche et redessine la grille.
func _on_search_changed(new_text: String):
	_search_text = new_text.strip_edges().to_lower()
	request_redraw()


# --- Construction de l'Interface ---

# 🔹 Ajoute les boutons Unequip All et Mass Delete dans l'en-tête.
func _build_header_buttons():
	var header = fuse_all_button.get_parent()
	unequip_all_button = Button.new()
	unequip_all_button.text = "Unequip All"
	unequip_all_button.pressed.connect(_on_unequip_all_pressed)
	header.add_child(unequip_all_button)
	equip_best_button = Button.new()
	equip_best_button.text = "Equip Best"
	equip_best_button.pressed.connect(_on_equip_best_pressed)
	header.add_child(equip_best_button)
	mass_delete_button = Button.new()
	mass_delete_button.text = "Mass Delete"
	mass_delete_button.toggle_mode = true
	mass_delete_button.toggled.connect(_set_mass_delete_mode)
	header.add_child(mass_delete_button)

# 🔹 Crée la barre du mode Mass Delete (compteur, quantité, boutons) sous la recherche.
func _build_mass_delete_bar():
	mass_delete_bar = HBoxContainer.new()
	mass_delete_bar.visible = false
	mass_delete_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	mass_delete_bar.add_theme_constant_override("separation", 16)
	var content = search_bar.get_parent()
	content.add_child(mass_delete_bar)
	content.move_child(mass_delete_bar, search_bar.get_index() + 1)
	mass_selection_label = Label.new()
	mass_delete_bar.add_child(mass_selection_label)
	_build_quantity_box()
	mass_confirm_button = Button.new()
	mass_confirm_button.pressed.connect(_on_mass_delete_confirm_pressed)
	mass_delete_bar.add_child(mass_confirm_button)
	var cancel_button = Button.new()
	cancel_button.text = "Annuler"
	cancel_button.pressed.connect(_set_mass_delete_mode.bind(false))
	mass_delete_bar.add_child(cancel_button)

# 🔹 Crée le slider à crans de quantité, avec au-dessus son nombre modifiable au clavier.
func _build_quantity_box():
	quantity_box = VBoxContainer.new()
	quantity_box.custom_minimum_size = Vector2(360, 0)
	mass_delete_bar.add_child(quantity_box)
	var quantity_row = HBoxContainer.new()
	quantity_row.alignment = BoxContainer.ALIGNMENT_CENTER
	quantity_box.add_child(quantity_row)
	quantity_edit = LineEdit.new()
	quantity_edit.custom_minimum_size = Vector2(70, 0)
	quantity_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	quantity_edit.flat = true
	quantity_edit.select_all_on_focus = true
	quantity_edit.tooltip_text = "Clique pour saisir la quantité au clavier"
	quantity_edit.text_submitted.connect(_on_quantity_typed)
	quantity_edit.focus_exited.connect(_on_quantity_focus_exited)
	quantity_row.add_child(quantity_edit)
	quantity_max_label = Label.new()
	quantity_row.add_child(quantity_max_label)
	quantity_slider = HSlider.new()
	quantity_slider.step = 1
	quantity_slider.ticks_on_borders = true
	quantity_slider.value_changed.connect(_on_quantity_slider_changed)
	quantity_box.add_child(quantity_slider)


# --- Mass Delete ---

# 🔹 Active ou quitte le mode Mass Delete, en vidant la sélection.
func _set_mass_delete_mode(enabled: bool):
	_mass_delete_mode = enabled
	mass_delete_button.set_pressed_no_signal(enabled)
	mass_delete_bar.visible = enabled
	_mass_active_key = ""
	for group_key in _mass_selection:
		if _slots_by_key.has(group_key):
			_slots_by_key[group_key].show_delete_mark(0)
	_mass_selection.clear()
	if enabled:
		_hide_details_panel()
	_refresh_mass_delete_bar()

# 🔹 Coche un groupe (tous ses exemplaires par défaut), ou le décoche s'il était déjà actif.
func _toggle_mass_selection(group_key: String):
	var pet_group = _get_group_from_key(group_key)
	if pet_group.is_empty():
		return
	var quantity = _mass_selection.get(group_key, 0)
	var was_active = group_key == _mass_active_key
	_mass_active_key = group_key
	if quantity == 0:
		_set_mass_quantity(group_key, pet_group.count)
	elif was_active or pet_group.count == 1:
		_set_mass_quantity(group_key, 0)
	else:
		_refresh_mass_delete_bar()

# 🔹 Fixe la quantité à supprimer d'un groupe, bornée par le nombre possédé.
func _set_mass_quantity(group_key: String, quantity: int):
	var pet_group = _get_group_from_key(group_key)
	if pet_group.is_empty():
		return
	var clamped = clampi(quantity, 0, pet_group.count)
	if clamped == 0:
		_mass_selection.erase(group_key)
	else:
		_mass_selection[group_key] = clamped
	if _slots_by_key.has(group_key):
		_slots_by_key[group_key].show_delete_mark(clamped)
	_refresh_mass_delete_bar()

# 🔹 Réaligne la sélection sur l'inventaire actuel et remet les marques sur les slots.
func _sync_mass_selection():
	for group_key in _mass_selection.keys():
		var pet_group = _get_group_from_key(group_key)
		if pet_group.is_empty():
			_mass_selection.erase(group_key)
			continue
		_mass_selection[group_key] = mini(_mass_selection[group_key], pet_group.count)
		if _slots_by_key.has(group_key):
			_slots_by_key[group_key].show_delete_mark(_mass_selection[group_key])
	_refresh_mass_delete_bar()

# 🔹 Met à jour le compteur, le bouton de suppression et le slider du groupe actif.
func _refresh_mass_delete_bar():
	var total = _get_mass_selection_total()
	mass_selection_label.text = "Sélection : %d pet(s)" % total
	mass_confirm_button.text = "Supprimer (%d)" % total
	mass_confirm_button.disabled = total == 0
	var active_group = _get_group_from_key(_mass_active_key)
	quantity_box.visible = not active_group.is_empty() and active_group.count > 1
	if not quantity_box.visible:
		return
	var quantity = _mass_selection.get(_mass_active_key, 0)
	quantity_slider.set_value_no_signal(0)
	quantity_slider.max_value = active_group.count
	quantity_slider.tick_count = mini(active_group.count + 1, MAX_SLIDER_TICKS)
	quantity_slider.set_value_no_signal(quantity)
	quantity_edit.text = str(quantity)
	quantity_max_label.text = "/ %d  %s (%s)" % [active_group.count, active_group.data.base_name, active_group.data.type.name]

# 🔹 Retourne le nombre total de pets cochés pour la suppression.
func _get_mass_selection_total() -> int:
	var total = 0
	for quantity in _mass_selection.values():
		total += quantity
	return total

# 🔹 Retourne les identifiants des pets non équipés correspondant à la sélection.
func _collect_mass_delete_ids() -> Array:
	var remaining = _mass_selection.duplicate()
	var ids_to_remove = []
	for pet_instance in DataManager.player_inventory:
		if pet_instance.unique_id in DataManager.equipped_pets:
			continue
		var group_key = _make_group_key(pet_instance)
		if remaining.get(group_key, 0) > 0:
			remaining[group_key] -= 1
			ids_to_remove.append(pet_instance.unique_id)
	return ids_to_remove

# 🔹 Supprime les pets cochés puis quitte le mode Mass Delete.
func _delete_mass_selection():
	var ids_to_remove = _collect_mass_delete_ids()
	_set_mass_delete_mode(false)
	if not ids_to_remove.is_empty():
		await Backend.delete_pets(ids_to_remove)


# --- UI Interne ---

# 🔹 Demande une confirmation avant une suppression, sauf si l'option est désactivée.
func _ask_delete_confirmation(question: String, on_confirmed: Callable):
	if not SaveManager.load_setting("gameplay/confirm_delete", true):
		on_confirmed.call()
		return
	var dialog = ConfirmationDialog.new()
	dialog.title = "Supprimer"
	dialog.dialog_text = question
	add_child(dialog)
	dialog.confirmed.connect(on_confirmed)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

# 🔹 Reconstruit la barre d'équipe avec un slot par place disponible.
func _redraw_team_bar():
	unequip_all_button.disabled = DataManager.equipped_pets.is_empty()
	PetVisuals.clear_children(team_bar_container)
	for i in range(DataManager.max_equipped_pets):
		var slot = TEAM_SLOT_SCENE.instantiate()
		team_bar_container.add_child(slot)
		slot.custom_minimum_size = TEAM_SLOT_SIZE
		var pet_instance = {}
		if i < DataManager.equipped_pets.size():
			pet_instance = DataManager.get_pet_by_id(DataManager.equipped_pets[i])
		if pet_instance.is_empty():
			slot.setup(null)
		else:
			slot.setup(pet_instance)
			slot.slot_clicked.connect(display_equipped_pet)

# 🔹 Remplit le panneau de détails pour un pet (groupe non équipé ou pet d'équipe).
func _show_details(pet_data: Dictionary, count_owned: int, is_equipped: bool):
	details_panel.visible = true
	var rarity_name = GameConfig.get_pet_rarity(pet_data.base_name)
	var count_text = "Équipé" if is_equipped else "x%d" % count_owned
	pet_name_label.text = "%s (%s) [%s]" % [pet_data.base_name, pet_data.type.name, count_text]
	rarity_label.text = rarity_name
	rarity_label.add_theme_color_override("font_color", GameConfig.RARITIES[rarity_name].color)
	chance_label.text = "(%s)" % NumberFormat.format_chance(GameConfig.get_combined_chance(pet_data))
	coin_boost_label.text = "Coin Boost: x%s" % pet_data.stats.CoinBoost
	luck_boost_label.text = "Luck Boost: x%s" % pet_data.stats.LuckBoost
	gem_boost_label.text = "Gem Boost: %.4f/s" % pet_data.stats.GemBoost
	_update_equip_button_state(is_equipped)
	_update_fuse_button_state(pet_data, count_owned, is_equipped)
	delete_button.disabled = is_equipped
	_update_details_model(pet_data)

# 🔹 Règle le bouton Equip / Unequip selon la sélection et les places libres.
func _update_equip_button_state(is_equipped: bool):
	if is_equipped:
		equip_button.text = "Unequip"
		equip_button.disabled = false
		return
	equip_button.text = "Equip"
	equip_button.disabled = DataManager.equipped_pets.size() >= DataManager.max_equipped_pets

# 🔹 Règle le bouton de fusion selon le nombre de pets possédés et le type suivant.
func _update_fuse_button_state(pet_data: Dictionary, count_owned: int, is_equipped: bool):
	fuse_button.visible = not is_equipped
	if is_equipped:
		return
	if GameConfig.get_type_by_order(pet_data.type.order + 1).is_empty():
		fuse_button.text = "Max Type"
		fuse_button.disabled = true
		return
	fuse_button.text = "Fuse: %d/%d" % [count_owned, GameConfig.FUSION_REQUIRED_AMOUNT]
	fuse_button.disabled = count_owned < GameConfig.FUSION_REQUIRED_AMOUNT

# 🔹 Affiche le modèle 3D du pet sélectionné, sans le recréer s'il est déjà affiché.
func _update_details_model(pet_data: Dictionary):
	var model_key = _make_group_key(pet_data)
	if model_key == _displayed_model_key and pet_holder.get_child_count() > 0:
		return
	_displayed_model_key = model_key
	PetVisuals.clear_children(pet_holder)
	pet_holder.add_child(PetVisuals.create_pet_model(pet_data.base_name, pet_data.type, PetVisuals.RENDER_LAYER_PET_PREVIEW))

# 🔹 Cache le panneau de détails et oublie la sélection.
func _hide_details_panel():
	details_panel.visible = false
	_selected_group_key = ""
	_selected_equipped_id = NO_PET_ID
	equip_button.text = "Equip"
	equip_button.disabled = true
	fuse_button.visible = false


# --- Groupement et Utilitaires ---

# 🔹 Retourne la clé de groupe (espèce + type) d'un pet.
func _make_group_key(pet_data: Dictionary) -> String:
	return "%s_%s" % [pet_data.base_name, pet_data.type.name]

# 🔹 Regroupe les pets non équipés par espèce et par type.
func _group_inventory():
	_grouped_inventory.clear()
	var temp_groups = {}
	for pet_instance in DataManager.player_inventory:
		if pet_instance.unique_id in DataManager.equipped_pets:
			continue
		var key = _make_group_key(pet_instance)
		if not temp_groups.has(key):
			temp_groups[key] = {
				"key": key,
				"data": pet_instance,
				"rarity_order": GameConfig.get_rarity_order(pet_instance.base_name),
				"count": 0,
				"first_id": pet_instance.unique_id
			}
		temp_groups[key].count += 1
	for group in temp_groups.values():
		_grouped_inventory.append(group)

# 🔹 Trie les groupes selon le critère choisi et met à jour le texte du bouton de tri.
func _sort_grouped_inventory():
	var sort_by = _sort_options[_current_sort_index]
	sort_by_button.text = "Trier par : %s" % sort_by.capitalize()
	equip_best_button.tooltip_text = "Équipe les meilleurs pets en %s" % (sort_by if sort_by in EQUIP_BEST_STATS else DEFAULT_EQUIP_BEST_STAT).capitalize()
	_grouped_inventory.sort_custom(func(a, b):
		match sort_by:
			"Rarity":
				return GameConfig.get_combined_chance(a.data) < GameConfig.get_combined_chance(b.data)
			"CoinBoost":
				return a.data.stats.CoinBoost > b.data.stats.CoinBoost
			"LuckBoost":
				return a.data.stats.LuckBoost > b.data.stats.LuckBoost
			"Count":
				return a.count > b.count
		return false)

# 🔹 Retourne les groupes qui correspondent au texte de recherche (espèce ou type).
func _get_filtered_groups() -> Array[Dictionary]:
	if _search_text.is_empty():
		return _grouped_inventory
	var filtered: Array[Dictionary] = []
	for group in _grouped_inventory:
		if group.data.base_name.to_lower().contains(_search_text) or group.data.type.name.to_lower().contains(_search_text):
			filtered.append(group)
	return filtered

# 🔹 Retourne le groupe correspondant à une clé, ou un dictionnaire vide.
func _get_group_from_key(key: String) -> Dictionary:
	for group in _grouped_inventory:
		if group.key == key:
			return group
	return {}

# 🔹 Supprime un seul exemplaire non équipé d'un groupe.
func _delete_one(group_key: String):
	var pet_group = _get_group_from_key(group_key)
	if pet_group.is_empty():
		return
	await Backend.delete_pets([pet_group.first_id])
