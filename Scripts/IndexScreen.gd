# IndexScreen.gd
extends PanelContainer

# --- Signaux ---
signal close_requested

# --- Constantes ---
const INDEX_SLOT_SCENE = preload("res://Scenes/IndexSlot.tscn")
const INDEX_REWARD_PANEL_SCENE = preload("res://Scenes/IndexRewardPanel.tscn")
const PETS_PER_ROW = 6

# --- Références aux Nœuds ---
@onready var index_container: VBoxContainer = %IndexContainer
@onready var close_button: Button = %CloseButton


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Connecte les signaux de base du panneau.
func _ready():
	close_button.pressed.connect(func(): close_requested.emit())
	visibility_changed.connect(_on_visibility_changed)


# --- Méthodes Publiques / de Contrôle ---

# 🔹 Construit ou reconstruit l'affichage complet de l'index des pets.
func build_index():
	# Nettoie l'affichage précédent.
	for child in index_container.get_children():
		child.queue_free()
	
	# Crée une section pour chaque œuf défini dans le jeu.
	var is_first_egg = true
	for egg_def in DataManager.EGG_DEFINITIONS:
		if not is_first_egg:
			_create_separator()
		
		_add_egg_section(egg_def)
		is_first_egg = false


# --- Fonctions de Rappel (Signal Callbacks) ---

# 🔹 Met à jour l'affichage de l'index uniquement lorsqu'il devient visible.
func _on_visibility_changed():
	if visible:
		build_index()


# --- Méthodes Internes de Construction de l'UI ---

# 🔹 Ajoute une section complète pour un œuf (titre + grille de pets).
func _add_egg_section(egg_definition: Dictionary):
	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 20)
	index_container.add_child(main_hbox)

	# --- PARTIE GAUCHE : Titre et Grille de Pets ---
	var left_vbox = VBoxContainer.new()
	main_hbox.add_child(left_vbox)

	# Ajoute le titre de l'œuf.
	var egg_title = Label.new()
	egg_title.text = egg_definition.name
	egg_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	egg_title.add_theme_font_size_override("font_size", 24)
	left_vbox.add_child(egg_title)
	
	# Crée et configure la grille pour les pets.
	var pet_grid = GridContainer.new()
	pet_grid.columns = PETS_PER_ROW
	pet_grid.add_theme_constant_override("h_separation", 10)
	pet_grid.add_theme_constant_override("v_separation", 10)
	left_vbox.add_child(pet_grid)

	# Remplit la grille avec les slots de pet (votre logique existante).
	for pet_info_in_egg in egg_definition.pets:
		var pet_name = pet_info_in_egg.name
		var is_discovered = DataManager.discovered_pets.has(pet_name)
		var is_secret = pet_name in egg_definition.secret_pets
		
		if not is_secret or (is_secret and is_discovered):
			var slot = INDEX_SLOT_SCENE.instantiate()
			pet_grid.add_child(slot)
			slot.setup(pet_name, is_discovered)
			
	# --- PARTIE DROITE : Panneau de Récompense ---
	var right_vbox = VBoxContainer.new()
	right_vbox.alignment = VBoxContainer.ALIGNMENT_CENTER
	main_hbox.add_child(right_vbox)
	
	var reward_panel = INDEX_REWARD_PANEL_SCENE.instantiate()
	right_vbox.add_child(reward_panel)
	reward_panel.setup(egg_definition.name)
	reward_panel.claim_requested.connect(_on_claim_reward_requested)

# 🔹 Crée et ajoute un séparateur visuel entre les sections d'œufs.
func _create_separator():
	var separator = Control.new()
	separator.custom_minimum_size.y = 40
	index_container.add_child(separator)

# 🔹 Gère une demande de réclamation de récompense.
func _on_claim_reward_requested(egg_name: String):
	DataManager.claim_index_reward(egg_name)
	# On reconstruit l'index pour mettre à jour l'état du bouton.
	build_index()
