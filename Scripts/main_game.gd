extends Control

# 🔹 Constante pour le préfabriqué de l'œuf
const EGG_SCENE = preload("res://Scenes/Egg.tscn")

# 🔹 Paramètres
@export var NumberOfEggMax = 12
@export var Luck = 1
@export var Speed = 1
@export var AutoHatch = false
@export var IsHatching = false

@export var global_egg_scale_multiplier = 0.5 # Changez cette valeur (ex: 1.0, 0.7, 1.2) pour ajuster la taille

# 🔹 RNG sécurisé (anti-triche)
var rng = RandomNumberGenerator.new()

# 🔹 Liste de pets avec leur chance (%)
@export var pets = [
	{"name":"Common", "chance":80.0, "model": preload("res://Assets/Pets/cat/Untitled (1).fbx")},
	{"name":"Rare", "chance":15.0, "model": preload("res://Assets/Pets/bee/BeePets.fbx")},
	{"name":"Legendary", "chance":4.9989, "model": preload("res://Assets/Egg.glb")},
	{"name":"Secret", "chance":0.001, "model": preload("res://Assets/Egg.glb")},
	{"name":"Mythic", "chance":0.0001, "model": preload("res://Assets/Egg.glb")}
]

# 🔹 Inventaire avec compteur
var inventory_count = { "Common": 0, "Rare": 0, "Legendary": 0, "Secret": 0, "Mythic": 0 }

# Machine à états simplifiée
enum GameState { HATCHING, INVENTORY }
var current_state = GameState.INVENTORY

# 🔹 Références UI et 3D
@onready var ui_root = $"UI root"
@onready var common_box = $"UI root/InventoryStack/Commons"
@onready var rare_box = $"UI root/InventoryStack/Rares"
@onready var legendary_box = $"UI root/InventoryStack/Legendaries"
@onready var secret_box = $"UI root/InventoryStack/Secrets"
@onready var mythic_box = $"UI root/InventoryStack/Mythics"
@onready var clear_button = $"UI root/ClearInventoryButton"
@onready var viewport_container = $SubViewportContainer
@onready var camera = $SubViewportContainer/SubViewport/HatchScene/Camera3D
@onready var egg_grid_container = $SubViewportContainer/SubViewport/HatchScene/EggGridContainer

# Pour garder la trace des œufs et pets actuellement à l'écran
var active_hatch_instances = []

func _ready():
	# Seed anti-triche
	rng.seed = Time.get_ticks_msec() + get_instance_id()
	clear_button.pressed.connect(_on_ClearInventoryButton_pressed)
	
	# MODIFIÉ : On commence toujours dans l'inventaire
	set_state(GameState.INVENTORY)
	
	print("🎮 Hatcher prêt !")

# Gestionnaire d'états : s'occupe de cacher/montrer les bonnes vues
func set_state(new_state: GameState):
	current_state = new_state
	match current_state:
		GameState.HATCHING:
			ui_root.visible = false
			viewport_container.visible = true
		GameState.INVENTORY:
			ui_root.visible = true
			viewport_container.visible = false

func _input(event):
	if event.is_action_pressed("hatch_one"): # E
		if not IsHatching and not AutoHatch:
			hatch_eggs(1)
	elif event.is_action_pressed("hatch_max"): # R
		if not IsHatching and not AutoHatch:
			hatch_eggs(NumberOfEggMax)
	elif event.is_action_pressed("toggle_auto"): # T
		AutoHatch = !AutoHatch
		if AutoHatch:
			print("🚀 Auto-Hatch activé")
			auto_hatch_loop()
		else:
			print("🛑 Auto-Hatch désactivé")

# 🔹 Tirer un pet
func hatch_pet() -> Dictionary:
	var roll = rng.randf_range(0.0001, 100.0)
	var cumulative = 0.0
	for pet_data in pets:
		cumulative += pet_data["chance"]
		if roll <= cumulative:
			return pet_data
	return pets[0] # Retourne "Common" en cas d'erreur


# ===================================================================
# LOGIQUE D'ÉCLOSION SIMULTANÉE
# ===================================================================

# 🔹 Ouvrir un certain nombre d'œufs
func hatch_eggs(count: int) -> void:
	if IsHatching:
		return
	IsHatching = true
	
	# 1. On change de vue pour aller vers la scène 3D
	set_state(GameState.HATCHING)
	# On attend une frame pour que la vue soit bien affichée avant de placer les objets
	await get_tree().process_frame
	
	# 2. Nettoyer les instances précédentes
	for instance in active_hatch_instances:
		if is_instance_valid(instance.node):
			instance.node.queue_free()
	active_hatch_instances.clear()
	
	# 3. Tirer tous les pets
	var pets_to_hatch = []
	for i in range(count):
		pets_to_hatch.append(hatch_pet())
		
	# 4. Placer les œufs sur la grille
	place_eggs_on_grid(pets_to_hatch)
	
	# 5. Jouer l'animation
	await play_simultaneous_hatch_animation()
	
	# 6. Mettre à jour l'inventaire (cela se fait en arrière-plan)
	for pet_data in pets_to_hatch:
		add_pet_to_inventory(pet_data["name"])
	
	# 7. Attendre un peu pour que le joueur voie les pets
	await get_tree().create_timer(1.5).timeout
	
	# 8. Nettoyer les modèles 3D
	for instance in active_hatch_instances:
		if is_instance_valid(instance.node):
			instance.node.queue_free()
	active_hatch_instances.clear()
	
	# 9. L'éclosion est finie, on peut en lancer une autre
	IsHatching = false
	
	# 10. Si on n'est pas en auto-hatch, on retourne à l'inventaire
	if not AutoHatch:
		set_state(GameState.INVENTORY)

# NOUVELLE FONCTION pour disposer les œufs en grille
func place_eggs_on_grid(pets_data: Array):
	var count = pets_data.size()
	if count == 0:
		return
	
	var cols = ceil(sqrt(count))
	var rows = ceil(count / float(cols))
	
	var viewport_size = viewport_container.size
	var cell_size_x = viewport_size.x / cols
	var cell_size_y = viewport_size.y / rows
	var square_cell_size = min(cell_size_x, cell_size_y)
	
	var total_grid_width = cols * square_cell_size
	var total_grid_height = rows * square_cell_size
	var x_offset = (viewport_size.x - total_grid_width) / 2.0
	var y_offset = (viewport_size.y - total_grid_height) / 2.0
	
	var plane = Plane(Vector3(0, 0, 1), 0)
	
	for i in range(count):
		var col = i % int(cols)
		var row = floor(i / cols)
		
		var current_x_offset = x_offset # On utilise l'offset général par défaut
		var is_last_row = (row == int(rows) - 1)
		if is_last_row:
			var items_in_last_row = count - (int(rows - 1) * int(cols))
			if items_in_last_row > 0:
				var last_row_width = items_in_last_row * square_cell_size
				# On calcule un offset spécial juste pour cette ligne
				current_x_offset = (viewport_size.x - last_row_width) / 2.0
		
		var screen_pos = Vector2(
			current_x_offset + (col * square_cell_size),
			y_offset + (row * square_cell_size)
		)
		
		screen_pos += Vector2(square_cell_size / 2.0, square_cell_size / 2.0)
		
		var ray_origin = camera.project_ray_origin(screen_pos)
		var ray_normal = camera.project_ray_normal(screen_pos)
		var world_pos = plane.intersects_ray(ray_origin, ray_normal)
		
		if world_pos != null:
			var egg_instance = EGG_SCENE.instantiate()
			
			var aabb = get_total_aabb(egg_instance)
			var original_max_dimension = max(aabb.size.x, aabb.size.y, aabb.size.z)
			
			var target_egg_size = get_3d_world_size_from_viewport(Vector2(square_cell_size, square_cell_size)).x

			var correct_scale_factor = 1.0
			if original_max_dimension > 0.001:
				correct_scale_factor = target_egg_size / original_max_dimension

			correct_scale_factor *= global_egg_scale_multiplier # Applique notre réglage manuel

			egg_instance.scale = Vector3.ONE * correct_scale_factor
			egg_instance.position = world_pos
			
			egg_grid_container.add_child(egg_instance)
			active_hatch_instances.append({"node": egg_instance, "pet_data": pets_data[i]})

func get_total_aabb(node: Node3D) -> AABB:
	var total_aabb = AABB()

	# D'abord, on vérifie si le nœud lui-même est visuel
	if node is VisualInstance3D:
		total_aabb = node.get_aabb()

	# Ensuite, on parcourt tous ses enfants
	for child in node.get_children():
		if child is Node3D: # On ne traite que les enfants 3D
			# On récupère l'AABB de l'enfant (et de ses propres enfants, par récursion)
			var child_aabb = get_total_aabb(child)

			# L'AABB de l'enfant est dans son propre espace local.
			# On doit la transformer pour la mettre dans l'espace du parent avant de la fusionner.
			child_aabb = child.transform * child_aabb

			# On fusionne l'AABB totale avec celle de l'enfant
			total_aabb = total_aabb.merge(child_aabb)

	return total_aabb

# NOUVELLE FONCTION D'ANIMATION SIMULTANÉE
func play_simultaneous_hatch_animation():
	if active_hatch_instances.is_empty():
		return

	# --- PARTIE 1: Basculement des œufs ---
	var anim_duration = 0.5
	var elapsed_time = 0.0
	var swing_amount = 0.3
	var swing_speed = 8.0

	while elapsed_time < anim_duration:
		var delta = get_process_delta_time()
		elapsed_time += delta
		
		# Applique l'animation à TOUS les œufs
		for instance in active_hatch_instances:
			var angle = sin(elapsed_time * swing_speed + instance.node.position.x) * swing_amount # Ajoute la position pour un léger décalage
			instance.node.rotation.y = angle
		
		await get_tree().process_frame

	# --- PARTIE 2: "Flash" - Révélation du pet ---
	for instance in active_hatch_instances:
		var egg_model = instance.node.find_child("Egg", true, false) # Trouve le modèle de l'œuf dans l'instance
		if egg_model:
			egg_model.visible = false # Cache l'œuf

		# Instancie et affiche le pet correspondant
		var pet_data = instance.pet_data
		if pet_data and pet_data.model:
			var pet_instance = pet_data.model.instantiate()
			# On peut ajouter le pet comme enfant de l'instance de l'œuf pour le positionner facilement
			instance.node.add_child(pet_instance)
			pet_instance.position = Vector3.ZERO # Le pet apparaît là où était l'œuf
			# Ajuste l'échelle du pet si nécessaire
			pet_instance.scale = Vector3.ONE * 0.5 # Exemple : met le pet à la moitié de la taille de l'oeuf

	# Petite pause pour voir le résultat
	await get_tree().create_timer(0.5).timeout

func get_3d_world_size_from_viewport(size_in_pixels: Vector2) -> Vector2:
	var plane = Plane(Vector3(0, 0, 1), 0)

	# Point d'origine (0,0)
	var origin_ray_o = camera.project_ray_origin(Vector2.ZERO)
	var origin_ray_n = camera.project_ray_normal(Vector2.ZERO)
	var pos0_3d = plane.intersects_ray(origin_ray_o, origin_ray_n)

	# Point correspondant à la taille en pixels
	var size_ray_o = camera.project_ray_origin(size_in_pixels)
	var size_ray_n = camera.project_ray_normal(size_in_pixels)
	var pos_size_3d = plane.intersects_ray(size_ray_o, size_ray_n)

	if pos0_3d != null and pos_size_3d != null:
		return Vector2(abs(pos_size_3d.x - pos0_3d.x), abs(pos_size_3d.y - pos0_3d.y))
	
	# Valeur de secours si la projection échoue
	return Vector2.ONE

# 🔹 Auto-hatch (boucle tant que AutoHatch = true)
func auto_hatch_loop() -> void:
	while AutoHatch:
		if not IsHatching:
			await hatch_eggs(NumberOfEggMax)
		else:
			await get_tree().process_frame
	
	# Quand la boucle AutoHatch se termine (l'utilisateur a appuyé sur T), on retourne à l'inventaire
	if current_state == GameState.HATCHING:
		set_state(GameState.INVENTORY)

# 🔹 Ajouter un pet à l’inventaire et UI
func add_pet_to_inventory(pet_name: String):
# Incrémente le compteur
	inventory_count[pet_name] += 1
	var count = inventory_count[pet_name]
	var text = "%s x%d" % [pet_name, count]

	# Détermine le conteneur correct
	var container
	match pet_name:
		"Common":
			container = common_box
		"Rare":
			container = rare_box
		"Legendary":
			container = legendary_box
		"Secret":
			container = secret_box
		"Mythic":
			container = mythic_box

	# Détermine la couleur
	var color
	match pet_name:
		"Common":
			color = Color.WHITE
		"Rare":
			color = Color.BLUE
		"Legendary":
			color = Color.ORANGE
		"Secret":
			color = Color.PURPLE
		"Mythic":
			color = Color.YELLOW

	# Si aucun label dans le container, on crée un nouveau
	if container.get_child_count() == 0:
		var label = Label.new()
		label.name = pet_name
		label.text = text
		label.add_theme_color_override("font_color", color)
		container.add_child(label)
	else:
		# Met à jour le label existant
		container.get_child(0).text = text

# 🔹 Vider l’inventaire
func _on_ClearInventoryButton_pressed():
	for key in inventory_count.keys():
		inventory_count[key] = 0
	for container in [common_box, rare_box, legendary_box, secret_box, mythic_box]:
		for child in container.get_children():
			child.queue_free()
