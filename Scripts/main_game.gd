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
@onready var inventory_stack: HBoxContainer = $"UI root/InventoryStack"
@onready var clear_button: Button = $"UI root/ClearInventoryButton"
@onready var viewport_container: SubViewportContainer = $SubViewportContainer
@onready var camera: Camera3D = $SubViewportContainer/SubViewport/HatchScene/Camera3D
@onready var egg_grid_container: Node3D = $SubViewportContainer/SubViewport/HatchScene/EggGridContainer


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
# 🔹 FONCTIONS PRINCIPALES DE GODOT (_ready, _input)
# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

# 🔹 Initialisation du jeu au lancement
func _ready():
	var crypto = Crypto.new()
	var random_bytes = crypto.generate_random_bytes(8)
	rng.seed = bytes_to_int(random_bytes)
	
	build_dynamic_inventory()
	
	clear_button.pressed.connect(_on_ClearInventoryButton_pressed)
	
	set_state(GameState.INVENTORY)
	print("🎮 Hatcher prêt avec un inventaire dynamique !")

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

# 🔹 Tire UN pet en utilisant une table de chances pré-calculée
func hatch_pet(pets_to_roll: Array) -> Dictionary:
	var roll = rng.randf_range(0.0, 100.0)
	var cumulative = 0.0
	for pet_data in pets_to_roll:
		cumulative += pet_data["chance"]
		if roll <= cumulative:
			return pet_data
	return pets[0]

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
	for child in inventory_stack.get_children():
		child.queue_free()
	inventory_count.clear()
	rarity_data_map.clear()
	
	rarities.sort_custom(func(a, b): return a["order"] < b["order"])
	
	for rarity_info in rarities:
		var rarity_name = rarity_info["name"]
		
		var new_container = VBoxContainer.new()
		new_container.name = rarity_name
		inventory_stack.add_child(new_container)
		
		rarity_data_map[rarity_name] = {
			"color": rarity_info["color"],
			"container_node": new_container
		}

	for pet_info in pets:
		inventory_count[pet_info["name"]] = 0

# 🔹 Ajoute un pet à l'inventaire visuel ou met à jour son compteur
func add_pet_to_inventory(pet_data: Dictionary):
	var pet_name = pet_data["name"]
	var pet_rarity = pet_data["rarity"]
	
	# 1. Incrémente le compteur pour ce pet spécifique.
	if inventory_count.has(pet_name):
		inventory_count[pet_name] += 1
	else:
		# Sécurité au cas où le pet n'aurait pas été initialisé.
		inventory_count[pet_name] = 1
	
	# 2. Récupère les données de la rareté du pet (couleur, conteneur).
	if not rarity_data_map.has(pet_rarity):
		printerr("Rareté '%s' non trouvée pour le pet '%s'. Vérifiez la configuration." % [pet_rarity, pet_name])
		return
	
	var rarity_info = rarity_data_map[pet_rarity]
	var container: VBoxContainer = rarity_info["container_node"]
	var color: Color = rarity_info["color"]
	
	# 3. Prépare le texte à afficher.
	var count = inventory_count[pet_name]
	var text_to_display = "%s x%d" % [pet_name, count]
	
	# 4. Cherche si un label pour ce pet existe déjà dans le bon conteneur.
	# La correction clé est ici : le troisième paramètre 'false' rend la recherche plus fiable pour les nœuds créés dynamiquement.
	var label_node: Label = container.find_child(pet_name, false, false)
	
	if label_node:
		# Le label existe, on met juste à jour son texte.
		label_node.text = text_to_display
	else:
		# Le label n'existe pas, on le crée et on l'ajoute.
		var new_label = Label.new()
		new_label.name = pet_name # Important pour le retrouver la prochaine fois.
		new_label.text = text_to_display
		new_label.add_theme_color_override("font_color", color)
		container.add_child(new_label)

# 🔹 Réinitialise les compteurs de pets et vide l'interface de l'inventaire
func _on_ClearInventoryButton_pressed():
	for pet_name in inventory_count:
		inventory_count[pet_name] = 0
		
	for rarity_name in rarity_data_map:
		var container = rarity_data_map[rarity_name]["container_node"]
		for child in container.get_children():
			child.queue_free()

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
