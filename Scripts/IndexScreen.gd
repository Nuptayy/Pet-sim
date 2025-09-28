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
	
# 🔹 Met à jour l'affichage de l'index uniquement lorsqu'il devient visible.
func _on_visibility_changed():
	if visible:
		build_index()

# --- Méthodes Publiques / de Contrôle ---

# 🔹 Construit ou reconstruit l'affichage complet de l'index, onglet par onglet.
func build_index():
	# Nettoie les anciens onglets immédiatement.
	for child in tab_container.get_children():
		child.free()
	
	# 1. Récupère la liste des types découverts.
	var discovered_types = DataManager.get_discovered_types() # On utilise la fonction qui trie
	
	# 2. Crée un onglet pour chaque type découvert.
	for type_name in discovered_types:
		_create_tab_for_type(type_name)

# --- Méthodes Internes de Construction de l'UI ---

# 🔹 Crée un onglet complet pour un type de pet spécifique (ex: "Golden").
func _create_tab_for_type(type_name: String):
	# Crée la page de l'onglet (un ScrollContainer).
	var scroll_container = ScrollContainer.new()
	scroll_container.name = type_name # Le nom du nœud devient le titre de l'onglet.
	tab_container.add_child(scroll_container)
	
	# Crée le conteneur vertical pour le contenu de la page.
	var content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(content_vbox)

	# Ajoute une section pour chaque œuf dans cet onglet.
	var is_first = true
	for egg_def in DataManager.EGG_DEFINITIONS:
		if not is_first:
			var separator = HSeparator.new()
			content_vbox.add_child(separator)
		
		_add_egg_section_to_tab(content_vbox, egg_def, type_name)
		is_first = false

# 🔹 Ajoute une section d'œuf (titre, récompense, grille) à un onglet spécifique.
func _add_egg_section_to_tab(parent_vbox: VBoxContainer, egg_def: Dictionary, type_name: String):
	# Crée le conteneur principal HBox.
	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 20)
	parent_vbox.add_child(main_hbox)

	# --- PARTIE GAUCHE : Titre et Grille ---
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

	# Remplit la grille, mais en vérifiant si le pet existe en ce type.
	for pet_info_in_egg in egg_def.pets:
		var pet_name = pet_info_in_egg.name
		# Un pet est "découvert" dans cet onglet si on le possède dans ce type spécifique.
		var is_discovered_in_this_type = _is_pet_discovered_as_type(pet_name, type_name)
		
		var is_secret = pet_name in egg_def.secret_pets
		if not is_secret or (is_secret and is_discovered_in_this_type):
			var slot = INDEX_SLOT_SCENE.instantiate()
			pet_grid.add_child(slot)
			# On passe le statut de découverte spécifique à ce type.
			slot.setup(pet_name, is_discovered_in_this_type)
	
	# --- PARTIE DROITE : Récompense ---
	# On n'affiche la récompense que si elle est définie pour ce type.
	if egg_def.rewards.has(type_name):
		var right_vbox = VBoxContainer.new()
		right_vbox.alignment = VBoxContainer.ALIGNMENT_CENTER
		main_hbox.add_child(right_vbox)
		
		var reward_panel = INDEX_REWARD_PANEL_SCENE.instantiate()
		right_vbox.add_child(reward_panel)
		# NOTE : Il faudra adapter IndexRewardPanel.gd pour qu'il prenne le type en paramètre.
		reward_panel.setup(egg_def.name, type_name) 
		reward_panel.claim_requested.connect(_on_claim_reward_requested)

# --- Fonctions Utilitaires ---

# 🔹 Vérifie si un pet spécifique a été découvert dans un type spécifique.
func _is_pet_discovered_as_type(pet_name: String, type_name: String) -> bool:
	# On regarde maintenant dans notre "mémoire" permanente.
	var pet_discoveries = DataManager.discovered_pets.get(pet_name)
	
	# Si on n'a jamais eu ce pet, ou si la donnée n'est pas un dictionnaire, on retourne false.
	if typeof(pet_discoveries) != TYPE_DICTIONARY:
		return false
		
	# On retourne vrai uniquement si la clé du type existe.
	return pet_discoveries.has(type_name)

# 🔹 Gère une demande de réclamation de récompense.
func _on_claim_reward_requested(egg_name: String, type_name: String):
	# NOTE : Il faudra adapter DataManager.claim_index_reward pour qu'il prenne le type.
	DataManager.claim_index_reward(egg_name, type_name)
	build_index()
