# IndexScreen.gd
extends PanelContainer

# --- Signaux ---
signal close_requested

# --- Constantes ---
const INDEX_SLOT_SCENE = preload("res://Scenes/IndexSlot.tscn")
const INDEX_REWARD_PANEL_SCENE = preload("res://Scenes/IndexRewardPanel.tscn")
const PETS_PER_ROW = 6

# --- Références aux Nœuds ---
@onready var tab_container: TabContainer = %IndexTabContainer
@onready var close_button: Button = %CloseButton


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Connecte les signaux de base du panneau.
func _ready():
	close_button.pressed.connect(func(): close_requested.emit())
	visibility_changed.connect(_on_visibility_changed)


# --- Méthodes Publiques ---

# 🔹 Construit ou reconstruit l'affichage complet de l'index, en gardant l'onglet ouvert.
func build_index():
	var previous_tab = tab_container.current_tab
	for child in tab_container.get_children():
		child.free()
	for type_name in DataManager.get_discovered_types():
		_create_tab_for_type(type_name)
	if previous_tab >= 0 and previous_tab < tab_container.get_tab_count():
		tab_container.current_tab = previous_tab


# --- Fonctions de Rappel (Signal Callbacks) ---

# 🔹 Met à jour l'affichage de l'index uniquement lorsqu'il devient visible.
func _on_visibility_changed():
	if is_visible_in_tree():
		build_index()

# 🔹 Réclame une récompense d'index auprès du backend, puis rafraîchit l'affichage.
func _on_claim_reward_requested(egg_name: String, type_name: String):
	await Backend.claim_index_reward(egg_name, type_name)
	if is_visible_in_tree():
		build_index()


# --- Méthodes Internes de Construction de l'UI ---

# 🔹 Crée un onglet complet pour un type de pet spécifique (ex: "Golden").
func _create_tab_for_type(type_name: String):
	var scroll_container = ScrollContainer.new()
	scroll_container.name = type_name
	tab_container.add_child(scroll_container)
	var content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(content_vbox)
	for egg_def in GameConfig.EGG_DEFINITIONS:
		if content_vbox.get_child_count() > 0:
			content_vbox.add_child(HSeparator.new())
		_add_egg_section_to_tab(content_vbox, egg_def, type_name)

# 🔹 Ajoute une section d'œuf (titre, grille de pets, récompense) à un onglet.
func _add_egg_section_to_tab(parent_vbox: VBoxContainer, egg_def: Dictionary, type_name: String):
	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 20)
	parent_vbox.add_child(main_hbox)
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(left_vbox)
	var egg_title = Label.new()
	egg_title.text = egg_def.name
	egg_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	egg_title.add_theme_font_size_override("font_size", 24)
	left_vbox.add_child(egg_title)
	var pet_grid = GridContainer.new()
	pet_grid.columns = PETS_PER_ROW
	left_vbox.add_child(pet_grid)
	var type_info = GameConfig.get_type_by_name(type_name)
	for pet_info_in_egg in egg_def.pets:
		var pet_name = pet_info_in_egg.name
		var is_discovered = DataManager.is_discovered(pet_name, type_name)
		if pet_name in egg_def.secret_pets and not is_discovered:
			continue
		var slot = INDEX_SLOT_SCENE.instantiate()
		pet_grid.add_child(slot)
		slot.setup(pet_name, type_info, is_discovered)
	if not egg_def.rewards.has(type_name):
		return
	var right_vbox = VBoxContainer.new()
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_child(right_vbox)
	var reward_panel = INDEX_REWARD_PANEL_SCENE.instantiate()
	right_vbox.add_child(reward_panel)
	reward_panel.setup(egg_def.name, type_name)
	reward_panel.claim_requested.connect(_on_claim_reward_requested)
