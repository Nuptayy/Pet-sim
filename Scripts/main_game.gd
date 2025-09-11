# Ce script gère toute la logique du jeu : éclosion, inventaire, animations et paramètres.
extends Control


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
# 🔹 CONFIGURATION DU JEU (MODIFIABLE DANS L'INSPECTEUR)
# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

# --- Groupe: Éclosion ---
@export var NumberOfEggMax = 12
@export var AutoHatch = false

# --- Groupe: Ressenti du Jeu ---
@export var Speed = 1 # Multiplicateur de vitesse des animations. 1.0 = normal.
@export var global_egg_scale_multiplier = 0.5 # Ajuste la taille globale des œufs.

# --- Groupe: Équilibrage ---
@export var Luck = 1.0 # Multiplicateur de chance pour les pets rares. 1.0 = normal.
@export var low_tier_rarities: Array[String] = ["Common", "Uncommon", "Rare", "Legendary"] # Raretés qui perdent de la chance.

# 🔹 Définit les propriétés de chaque rareté (couleur, ordre d'affichage).
@export var rarities: Array[Dictionary] = [
	{"name": "Common",      "color": Color.WHITE,          "order": 0},
	{"name": "Uncommon",    "color": Color.GREEN,          "order": 1},
	{"name": "Rare",        "color": Color.BLUE,           "order": 2},
	{"name": "Legendary",   "color": Color.ORANGE,         "order": 3},
	{"name": "Secret",      "color": Color.PURPLE,         "order": 4},
	{"name": "Mythic",      "color": Color.YELLOW,         "order": 5},
	{"name": "Divine",      "color": Color.SKY_BLUE,       "order": 6},
	{"name": "Insane",      "color": Color.DARK_RED,       "order": 7},
	{"name": "WTF",         "color": Color.GOLD,           "order": 8},
	{"name": "GodLike",     "color": Color.REBECCA_PURPLE, "order": 9},
	{"name": "Impossible",  "color": Color.LIGHT_YELLOW,   "order": 10}
]

# 🔹 Définit chaque pet individuel, sa chance, son modèle et sa rareté.
@export var pets: Array[Dictionary] = [
	{"name":"Cat",       "chance": 50.0,    "model": preload("res://Assets/Pets/cat/Untitled (1).fbx"),  "rarity": "Common"},
	{"name":"Rabbit",    "chance": 30.0,    "model": preload("res://Assets/Pets/Rabbit/Untitled.glb"),   "rarity": "Uncommon"},
	{"name":"Bee",       "chance": 15.0,    "model": preload("res://Assets/Pets/bee/BeePets.fbx"),       "rarity": "Rare"},
	{"name":"Test1",     "chance": 4.9989,  "model": preload("res://Assets/Egg.glb"),                    "rarity": "Legendary"},
	{"name":"Test2",     "chance": 0.001,   "model": preload("res://Assets/Egg.glb"),                    "rarity": "Secret"},
	{"name":"Test3",     "chance": 0.0001,  "model": preload("res://Assets/Egg.glb"),                    "rarity": "Mythic"}
]

# 🔹 Définit les différents types de pet, leurs chances, et leur ordre d'affichage.
@export var pet_types: Array[Dictionary] = [
	{"name": "Classic", "chance": 88.89,"effect_type": "none",   "value": null,       "order": 0},
	{"name": "Golden",  "chance": 10.0, "effect_type": "color",  "value": Color.GOLD, "order": 1},
	{"name": "Rainbow", "chance": 1.0,  "effect_type": "shader", "value": "res://Shaders/rainbow_effect.gdshader", "order": 2},
	{"name": "Glitch",  "chance": 0.1,  "effect_type": "shader", "value": "res://Shaders/glitch_effect.gdshader",  "order": 3},
	{"name": "Virus",   "chance": 0.01, "effect_type": "shader", "value": "res://Shaders/virus_effect.gdshader",   "order": 4}
]

# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
# 🔹 VARIABLES INTERNES DU SYSTÈME
# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

const EGG_SCENE = preload("res://Scenes/Egg.tscn")

var IsHatching = false
enum GameState { HATCHING, INVENTORY }
var current_state = GameState.INVENTORY
var rng = RandomNumberGenerator.new()

var inventory_count = {}
var rarity_data_map = {}
var active_hatch_instances = []

@onready var ui_root: Control = $"UI root"
@onready var inventory_stack: VBoxContainer = $"UI root/InventoryStack"
@onready var clear_button: Button = $"UI root/ClearInventoryButton"
@onready var viewport_container: SubViewportContainer = $SubViewportContainer
@onready var camera: Camera3D = $SubViewportContainer/SubViewport/HatchScene/Camera3D
@onready var egg_grid_container: Node3D = $SubViewportContainer/SubViewport/HatchScene/EggGridContainer


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
# 🔹 FONCTIONS PRINCIPALES DE GODOT (_ready, _input)
# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

# 🔹 Initialisation du jeu au lancement
# 🔹 Initialisation du jeu au lancement
func _ready():
	var crypto = Crypto.new()
	var random_bytes = crypto.generate_random_bytes(8)
	rng.seed = bytes_to_int(random_bytes)
	
	build_dynamic_inventory()
	
	clear_button.pressed.connect(_on_ClearInventoryButton_pressed)
	
	set_state(GameState.INVENTORY)
	print("🎮 Hatcher prêt avec un inventaire basé sur les pets !")

# 🔹 Gère les entrées du joueur à chaque frame
func _input(event):
	if event.is_action_pressed("toggle_auto"):
		if AutoHatch:
			AutoHatch = false
			print("🛑 Auto-Hatch désactivé par l'utilisateur.")
			return
			
	if current_state == GameState.INVENTORY and not IsHatching:
		if event.is_action_pressed("hatch_one"):
			hatch_eggs(1)
		elif event.is_action_pressed("hatch_max"):
			hatch_eggs(NumberOfEggMax)
		elif event.is_action_pressed("toggle_auto"):
			AutoHatch = true
			print("🚀 Auto-Hatch activé")
			auto_hatch_loop()


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
# 🔹 LOGIQUE D'ÉCLOSION (HATCHING)
# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

# 🔹 Fonction principale qui orchestre l'ouverture d'un certain nombre d'œufs
func hatch_eggs(count: int) -> void:
	if IsHatching: return
	IsHatching = true
	
	set_state(GameState.HATCHING)
	await get_tree().process_frame
	
	for instance in active_hatch_instances:
		if is_instance_valid(instance.node):
			instance.node.queue_free()
	active_hatch_instances.clear()
	
	var lucky_pets_table = get_pets_with_luck()
	var pets_to_hatch = []
	for i in range(count):
		pets_to_hatch.append(hatch_pet(lucky_pets_table))
 
	place_eggs_on_grid(pets_to_hatch)
	await play_simultaneous_hatch_animation()
	
	for pet_data in pets_to_hatch:
		add_pet_to_inventory(pet_data)
	
	var safe_speed = max(Speed, 1.0)
	await get_tree().create_timer(1.5 / safe_speed).timeout
	
	for instance in active_hatch_instances:
		if is_instance_valid(instance.node):
			instance.node.queue_free()
	active_hatch_instances.clear()
	
	IsHatching = false
	if not AutoHatch:
		set_state(GameState.INVENTORY)

# 🔹 Boucle pour l'éclosion automatique
func auto_hatch_loop() -> void:
	while AutoHatch:
		if not IsHatching:
			await hatch_eggs(NumberOfEggMax)
		else:
			await get_tree().process_frame
	if current_state == GameState.HATCHING:
		set_state(GameState.INVENTORY)


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
# 🔹 CALCULS DE CHANCE (LUCK)
# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

# 🔹 Tire UN pet ET son type, en utilisant une table de chances pré-calculée
func hatch_pet(pets_to_roll: Array) -> Dictionary:
	var roll = rng.randf_range(0.0, 100.0)
	var cumulative = 0.0
	for pet_data in pets_to_roll:
		cumulative += pet_data["chance"]
		if roll <= cumulative:
			# Une fois le pet tiré, on tire son type.
			var final_pet_data = pet_data.duplicate()
			final_pet_data["type"] = roll_pet_type()
			return final_pet_data
			
	# Sécurité : en cas d'erreur, retourne le premier pet avec le type Classic.
	var fallback_pet = pets[0].duplicate()
	fallback_pet["type"] = pet_types.back() # .back() récupère le dernier élément (Classic)
	return fallback_pet

# 🔹 Calcule une table de chances temporaire, modifiée par le paramètre 'Luck'
func get_pets_with_luck() -> Array:
	var pets_copy = pets.duplicate(true)
	var low_tiers = []
	var high_tiers = []
	for pet in pets_copy:
		if pet["rarity"] in low_tier_rarities:
			low_tiers.append(pet)
		else:
			high_tiers.append(pet)
	var total_chance_boost = 0.0
	for pet in high_tiers:
		var original_chance = pet["chance"]
		var new_chance = original_chance * max(Luck, 1.0)
		var boost = new_chance - original_chance
		total_chance_boost += boost
		pet["chance"] = new_chance
	var low_tier_chance_pool = 0.0
	for pet in low_tiers:
		low_tier_chance_pool += pet["chance"]
	if low_tier_chance_pool > 0.001:
		for pet in low_tiers:
			var proportion_of_pool = pet["chance"] / low_tier_chance_pool
			var penalty = total_chance_boost * proportion_of_pool
			pet["chance"] = max(0.1, pet["chance"] - penalty)
	var final_pets = low_tiers + high_tiers
	var current_total = 0.0
	for pet in final_pets:
		current_total += pet["chance"]
	if current_total > 0:
		var scale_factor = 100.0 / current_total
		for pet in final_pets:
			pet["chance"] *= scale_factor
	else:
		return pets.duplicate(true)
	return final_pets


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
# 🔹 ANIMATION ET PLACEMENT 3D
# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

# 🔹 Joue la cinématique de balancement et de révélation pour tous les œufs
func play_simultaneous_hatch_animation():
	if active_hatch_instances.is_empty(): return
	
	var safe_speed = max(Speed, 1.0)
	var anim_duration = 1.0 / safe_speed
	var elapsed_time = 0.0
	var swing_amount = 0.3
	var swing_speed = 8.0
	
	while elapsed_time < anim_duration:
		elapsed_time += get_process_delta_time()
		var angle = sin(elapsed_time * swing_speed) * swing_amount
		for instance in active_hatch_instances:
			instance.node.rotation.y = angle
		await get_tree().process_frame

	for instance in active_hatch_instances:
		var egg_model = instance.node.find_child("Egg", true, false)
		if egg_model:
			egg_model.visible = false

		var pet_data = instance.pet_data
		if pet_data and pet_data.model:
			var pet_instance = pet_data.model.instantiate()
			instance.node.add_child(pet_instance)
			pet_instance.position = Vector3.ZERO
			pet_instance.scale = Vector3.ONE * 0.5
			# Applique l'effet visuel (Golden, Rainbow, etc.)
			apply_visual_effect(pet_instance, pet_data["type"])

	await get_tree().create_timer(0.5 / safe_speed).timeout

# 🔹 Calcule et place les instances d'œufs dans une grille centrée à l'écran
func place_eggs_on_grid(pets_data: Array):
	var count = pets_data.size()
	if count == 0: return
	var temp_egg = EGG_SCENE.instantiate()
	var egg_aabb = get_total_aabb(temp_egg)
	var egg_original_max_dim = max(egg_aabb.size.x, egg_aabb.size.y, egg_aabb.size.z)
	temp_egg.queue_free()
	var cols = ceil(sqrt(count))
	var rows = ceil(count / float(cols))
	var viewport_size = viewport_container.size
	var square_cell_size = min(viewport_size.x / cols, viewport_size.y / rows)
	var total_grid_width = cols * square_cell_size
	var total_grid_height = rows * square_cell_size
	var x_offset = (viewport_size.x - total_grid_width) / 2.0
	var y_offset = (viewport_size.y - total_grid_height) / 2.0
	var plane = Plane(Vector3(0, 0, 1), 0)
	for i in range(count):
		var col = i % int(cols)
		var row = floor(i / cols)
		var current_x_offset = x_offset
		if row == int(rows) - 1:
			var items_in_last_row = count - (int(rows - 1) * int(cols))
			if items_in_last_row > 0:
				var last_row_width = items_in_last_row * square_cell_size
				current_x_offset = (viewport_size.x - last_row_width) / 2.0
		var screen_pos = Vector2(current_x_offset + (col * square_cell_size), y_offset + (row * square_cell_size))
		screen_pos += Vector2(square_cell_size / 2.0, square_cell_size / 2.0)
		var ray_origin = camera.project_ray_origin(screen_pos)
		var ray_normal = camera.project_ray_normal(screen_pos)
		var world_pos = plane.intersects_ray(ray_origin, ray_normal)
		if world_pos != null:
			var egg_instance = EGG_SCENE.instantiate()
			var target_egg_size = get_3d_world_size_from_viewport(Vector2(square_cell_size, square_cell_size)).x
			var correct_scale_factor = 1.0
			if egg_original_max_dim > 0.001:
				correct_scale_factor = target_egg_size / egg_original_max_dim
			correct_scale_factor *= global_egg_scale_multiplier
			egg_instance.scale = Vector3.ONE * correct_scale_factor
			egg_instance.position = world_pos
			egg_grid_container.add_child(egg_instance)
			active_hatch_instances.append({"node": egg_instance, "pet_data": pets_data[i]})


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
# 🔹 GESTION DE L'INVENTAIRE ET DE L'INTERFACE (UI)
# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

# 🔹 Construit l'interface de l'inventaire et les données associées au démarrage
func build_dynamic_inventory():
	# 1. Prépare les données de base.
	inventory_count.clear()
	rarity_data_map.clear()
	rarities.sort_custom(func(a, b): return a["order"] < b["order"])
	for rarity_info in rarities:
		rarity_data_map[rarity_info["name"]] = {"color": rarity_info["color"]}
		
	# 2. Vide les anciens nœuds.
	for child in inventory_stack.get_children():
		child.queue_free()
	
	# 3. Calcule la largeur minimale nécessaire pour chaque colonne.
	var min_col_width = calculate_minimum_column_width()

	# 4. Crée une ligne (HBoxContainer) pour les totaux.
	var totals_row = HBoxContainer.new()
	totals_row.name = "TotalsRow"
	inventory_stack.add_child(totals_row)
	for pet_info in pets:
		var pet_name = pet_info["name"]
		var total_label = Label.new()
		total_label.name = "%s_TotalLabel" % pet_name
		total_label.custom_minimum_size.x = min_col_width
		total_label.visible = false
		var pet_rarity_info = rarity_data_map.get(pet_info["rarity"])
		if pet_rarity_info:
			total_label.add_theme_color_override("font_color", pet_rarity_info["color"])
		totals_row.add_child(total_label)
		
	# 5. Crée une ligne (HBoxContainer) pour chaque type de pet.
	var display_sorted_types = pet_types.duplicate(true)
	display_sorted_types.sort_custom(func(a, b): return a["order"] < b["order"])
	
	for type_info in display_sorted_types:
		var type_name = type_info["name"]
		var type_row = HBoxContainer.new()
		type_row.name = "%sRow" % type_name
		inventory_stack.add_child(type_row)
		for pet_info in pets:
			var pet_name = pet_info["name"]
			var type_label = Label.new()
			type_label.name = "%s_%sLabel" % [pet_name, type_name]
			type_label.custom_minimum_size.x = min_col_width
			type_label.visible = false
			type_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			type_row.add_child(type_label)
			
	# 6. Initialise les compteurs à zéro.
	for pet_info in pets:
		var pet_name = pet_info["name"]
		inventory_count[pet_name] = {"total": 0}
		for type_info in pet_types:
			inventory_count[pet_name][type_info["name"]] = 0
			
	# 5. Initialise les compteurs à zéro.
	for pet_info in pets:
		var pet_name = pet_info["name"]
		inventory_count[pet_name] = {"total": 0}
		for type_info in pet_types:
			inventory_count[pet_name][type_info["name"]] = 0

# 🔹 Ajoute un pet à l'inventaire visuel ou met à jour son compteur
func add_pet_to_inventory(pet_data: Dictionary):
	var pet_name = pet_data["name"]
	var type_name = pet_data["type"]["name"]
	
	if not inventory_count.has(pet_name): return
	
	# 1. Met à jour les compteurs.
	inventory_count[pet_name]["total"] += 1
	inventory_count[pet_name][type_name] += 1
	
	# 2. Met à jour le label du total dans la bonne ligne.
	var totals_row: HBoxContainer = inventory_stack.find_child("TotalsRow", false, false)
	if totals_row:
		var total_label: Label = totals_row.find_child("%s_TotalLabel" % pet_name, false, false)
		if total_label:
			total_label.text = "%s x%d" % [pet_name, inventory_count[pet_name]["total"]]
			total_label.visible = true

	# 3. Met à jour le label du type dans la bonne ligne.
	var type_row: HBoxContainer = inventory_stack.find_child("%sRow" % type_name, false, false)
	if type_row:
		var type_label: Label = type_row.find_child("%s_%sLabel" % [pet_name, type_name], false, false)
		if type_label:
			type_label.text = "%s: %d" % [type_name, inventory_count[pet_name][type_name]]
			type_label.visible = true

# 🔹 Réinitialise les compteurs de pets et vide l'interface de l'inventaire
func _on_ClearInventoryButton_pressed():
	for pet_name in inventory_count:
		inventory_count[pet_name]["total"] = 0
		var totals_row: HBoxContainer = inventory_stack.find_child("TotalsRow", false, false)
		if totals_row:
			var total_label: Label = totals_row.find_child("%s_TotalLabel" % pet_name, false, false)
			if total_label:
				total_label.visible = false
		
		for type_info in pet_types:
			inventory_count[pet_name][type_info["name"]] = 0
			var type_row: HBoxContainer = inventory_stack.find_child("%sRow" % type_info["name"], false, false)
			if type_row:
				var type_label: Label = type_row.find_child("%s_%sLabel" % [pet_name, type_info["name"]], false, false)
				if type_label:
					type_label.visible = false

# 🔹 Gère le changement d'état visuel du jeu (HATCHING vs INVENTORY)
func set_state(new_state: GameState):
	current_state = new_state
	match current_state:
		GameState.HATCHING:
			ui_root.visible = false
			viewport_container.visible = true
		GameState.INVENTORY:
			ui_root.visible = true
			viewport_container.visible = false


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
# 🔹 FONCTIONS UTILITAIRES
# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

# 🔹 Calcule la "boîte" englobant un nœud 3D et tous ses enfants visuels
func get_total_aabb(node: Node3D) -> AABB:
	var total_aabb = AABB()
	if node is VisualInstance3D:
		total_aabb = node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var child_aabb = get_total_aabb(child)
			child_aabb = child.transform * child_aabb
			total_aabb = total_aabb.merge(child_aabb)
	return total_aabb

# 🔹 Convertit un tableau d'octets en un entier 64-bit pour un seed
func bytes_to_int(bytes: PackedByteArray) -> int:
	var integer: int = 0
	for i in min(bytes.size(), 8):
		integer = (integer << 8) | bytes[i]
	return integer

# 🔹 Projette une taille en pixels 2D vers une taille dans le monde 3D
func get_3d_world_size_from_viewport(size_in_pixels: Vector2) -> Vector2:
	var plane = Plane(Vector3(0, 0, 1), 0)
	var origin_ray_o = camera.project_ray_origin(Vector2.ZERO)
	var origin_ray_n = camera.project_ray_normal(Vector2.ZERO)
	var pos0_3d = plane.intersects_ray(origin_ray_o, origin_ray_n)
	var size_ray_o = camera.project_ray_origin(size_in_pixels)
	var size_ray_n = camera.project_ray_normal(size_in_pixels)
	var pos_size_3d = plane.intersects_ray(size_ray_o, size_ray_n)
	if pos0_3d != null and pos_size_3d != null:
		return Vector2(abs(pos_size_3d.x - pos0_3d.x), abs(pos_size_3d.y - pos0_3d.y))
	return Vector2.ONE

# 🔹 Calcule la largeur de colonne minimale nécessaire pour éviter que le texte ne soit coupé
func calculate_minimum_column_width() -> float:
	var temp_label = Label.new()
	var max_width = 0.0
	
	# Teste le texte le plus long possible pour les totaux et les types
	var longest_pet_name = ""
	for pet in pets:
		if pet["name"].length() > longest_pet_name.length():
			longest_pet_name = pet["name"]
			
	var longest_type_name = ""
	for type in pet_types:
		if type["name"].length() > longest_type_name.length():
			longest_type_name = type["name"]
			
	# Simule le texte le plus long et mesure sa largeur
	temp_label.text = "%s x9999" % longest_pet_name
	max_width = max(max_width, temp_label.get_minimum_size().x)
	
	temp_label.text = "%s: 9999" % longest_type_name
	max_width = max(max_width, temp_label.get_minimum_size().x)
	
	temp_label.queue_free()
	
	# Ajoute un petit padding pour être sûr
	return max_width + 10 


# 🔹 Tire un "type" de pet en utilisant un système de probabilités cumulées
func roll_pet_type() -> Dictionary:
	# On fait UN SEUL tirage de dé, un nombre entre 0.0 et 100.0.
	var roll = rng.randf_range(0.0, 100.0)
	var cumulative = 0.0
	
	# On parcourt la liste des types
	for type_data in pet_types:
		cumulative += type_data["chance"]
		# On vérifie si notre lancer de dé tombe dans la tranche de ce type
		if roll <= cumulative:
			return type_data # On a trouvé notre type, on le retourne.
	
	# Sécurité : si la somme des chances n'est pas 100, on retourne le premier type de la liste.
	return pet_types[0]

# 🔹 Applique un effet visuel à un modèle de pet en fonction de son type
func apply_visual_effect(pet_node: Node3D, type_info: Dictionary):
	var mesh_instance = find_mesh_recursively(pet_node)
	if not mesh_instance:
		printerr("Impossible de trouver un MeshInstance3D pour appliquer l'effet visuel sur ", pet_node.name)
		return
		
	var effect_type = type_info["effect_type"]
	var effect_value = type_info["value"]
	
	match effect_type:
		"none":
			pass
		"color":
			# Parcourt toutes les surfaces du mesh pour appliquer la couleur.
			for i in range(mesh_instance.get_surface_override_material_count()):
				var original_material = mesh_instance.get_surface_override_material(i)
				
				# Duplique le matériau pour ne pas affecter d'autres instances.
				var new_material = original_material.duplicate() if original_material else StandardMaterial3D.new()
				
				if new_material is StandardMaterial3D:
					new_material.albedo_color = effect_value
					# Important : on applique le nouveau matériau dupliqué.
					mesh_instance.set_surface_override_material(i, new_material)
		"shader":
			var shader = load(effect_value) as Shader
			if shader:
				var shader_material = ShaderMaterial.new()
				shader_material.shader = shader
				# Applique le shader à toutes les surfaces.
				for i in range(mesh_instance.get_surface_override_material_count()):
					mesh_instance.set_surface_override_material(i, shader_material)
			else:
				printerr("Impossible de charger le shader depuis le chemin: ", effect_value)

# 🔹 Fonction utilitaire pour trouver la première instance de MeshInstance3D dans un nœud et ses enfants
func find_mesh_recursively(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var mesh = find_mesh_recursively(child)
		if mesh:
			return mesh
	return null
