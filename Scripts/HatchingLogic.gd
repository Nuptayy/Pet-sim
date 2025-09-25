# HatchingLogic.gd
extends Node

# --- Signaux ---
signal animation_started
signal animation_finished

# --- Constantes ---
const RED_CROSS_TEXTURE = preload("res://Assets/UI/red_cross.png")

# --- Paramètres de Jeu ---
@export var base_hatch_max: int = 12
@export var global_egg_scale_multiplier: float = 0.5
@export var low_tier_rarities: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

# --- État Interne ---
var NumberOfEggMax: int = 0  # Valeur calculée au démarrage par Main.gd
var total_luck_boost: float = 1.0 # Mis à jour avant chaque éclosion
var is_hatching: bool = false
var auto_hatch_enabled: bool = false
var active_hatch_instances: Array[Dictionary] = []
var rng = RandomNumberGenerator.new()

# --- Références Externes (fournies par Main.gd) ---
var camera: Camera3D
var egg_grid_container: Node3D
var viewport_container: Viewport


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Initialise le générateur de nombres aléatoires avec une seed unique.
func _ready():
	var crypto = Crypto.new()
	var random_bytes = crypto.generate_random_bytes(8)
	rng.seed = _bytes_to_int(random_bytes)


# ==============================================================================
# 1. ORCHESTRATION DE L'ÉCLOSION
# ==============================================================================

# 🔹 Point d'entrée principal qui reçoit les demandes d'éclosion de l'UI.
func on_hatch_requested(egg_name: String, count: int):
	if count == -1: # Code spécial pour basculer l'auto-hatch
		_toggle_auto_hatch(egg_name)
	else:
		_start_hatch_sequence(egg_name, count)

# 🔹 Démarre et gère la boucle d'éclosion automatique.
func _toggle_auto_hatch(egg_name: String):
	auto_hatch_enabled = not auto_hatch_enabled
	
	if auto_hatch_enabled:
		print("🚀 Auto-Hatch activé pour %s" % egg_name)
		# On lance la boucle sans attendre la fin (`await`)
		_auto_hatch_loop(egg_name)
	else:
		print("🛑 Auto-Hatch désactivé manuellement.")

# 🔹 Exécute la boucle d'éclosion automatique tant qu'elle est active.
func _auto_hatch_loop(egg_name: String):
	while auto_hatch_enabled:
		if not is_hatching:
			var success = await _start_hatch_sequence(egg_name, NumberOfEggMax)
			if not success:
				auto_hatch_enabled = false
				print("🛑 Auto-Hatch désactivé (fonds insuffisants ou autre erreur).")
				break # Sort de la boucle
		
		# Attend la prochaine frame pour ne pas bloquer le jeu.
		await get_tree().process_frame

# 🔹 Orchestre une seule séquence complète d'éclosion (de la vérification au nettoyage).
func _start_hatch_sequence(egg_name: String, count: int) -> bool:
	if is_hatching: return false
	
	var egg_def = _get_egg_definition(egg_name)
	if egg_def.is_empty():
		printerr("Définition non trouvée pour l'œuf: ", egg_name)
		return false

	var total_cost = egg_def.cost * count
	if DataManager.coins < total_cost:
		print("Pas assez de Coins ! Requis: %d, Possédés: %d" % [total_cost, int(DataManager.coins)])
		# TODO: Ajouter un feedback visuel ici (ex: faire trembler le bouton en rouge).
		return false
	
	# --- La séquence d'éclosion peut commencer ---
	is_hatching = true
	animation_started.emit()
	
	# Préparation
	DataManager.coins -= total_cost
	DataManager.increment_eggs_hatched(count)
	self.total_luck_boost = DataManager.get_total_luck_boost()
	_cleanup_previous_instances()
	
	# Tirage et Animation
	var pets_to_hatch = _roll_all_pets(egg_name, count)
	_place_eggs_on_grid(pets_to_hatch, egg_def.model)
	await _play_hatch_animation()
	
	# Finalisation
	_add_hatched_pets_to_inventory(pets_to_hatch)
	var safe_speed = max(DataManager.get_total_speed_boost(), 1.0)
	await get_tree().create_timer(0.25 / safe_speed).timeout
	_cleanup_previous_instances()
	
	is_hatching = false
	if not auto_hatch_enabled:
		animation_finished.emit()
		
	return true


# ==============================================================================
# 2. FONCTIONS DE TIRAGE (GATCHA)
# ==============================================================================

# 🔹 Prépare et effectue le tirage pour un nombre donné d'œufs.
func _roll_all_pets(egg_name: String, count: int) -> Array[Dictionary]:
	var lucky_pets_table = _get_pets_with_luck(egg_name)
	var pets_to_hatch: Array[Dictionary] = []
	for i in range(count):
		pets_to_hatch.append(_roll_one_pet(lucky_pets_table))

	# Applique les filtres d'auto-delete.
	var filters = DataManager.auto_delete_filters.get(egg_name, {})
	for pet_data in pets_to_hatch:
		var pet_def = DataManager.PET_DEFINITIONS[pet_data.base_name]
		var rarity = pet_def.rarity
		var type_name = pet_data.type.name
		pet_data["to_be_deleted"] = (filters.has(rarity) and type_name in filters[rarity])
		
	return pets_to_hatch

# 🔹 Tire UN pet et son type à partir d'une table de chances.
func _roll_one_pet(pets_to_roll: Array) -> Dictionary:
	var roll = rng.randf_range(0.0, 100.0)
	var cumulative = 0.0
	
	for pet_data in pets_to_roll:
		cumulative += pet_data.chance
		if roll <= cumulative:
			var final_pet_data = pet_data.duplicate()
			final_pet_data.base_name = pet_data.name
			final_pet_data.type = _roll_pet_type()
			return final_pet_data
			
	# Solution de secours si une erreur de calcul arrive.
	var fallback_pet = pets_to_roll[0].duplicate()
	fallback_pet.base_name = pets_to_roll[0].name
	fallback_pet.type = DataManager.PET_TYPES.back()
	return fallback_pet

# 🔹 Tire un type de pet (Classic, Golden, etc.) en se basant sur leurs chances.
func _roll_pet_type() -> Dictionary:
	var roll = rng.randf_range(0.0, 100.0)
	var cumulative = 0.0
	
	for type_data in DataManager.PET_TYPES:
		cumulative += type_data.chance
		if roll <= cumulative:
			return type_data
			
	return DataManager.PET_TYPES[0] # Classic par défaut

# 🔹 Génère une table de butin temporaire modifiée par la chance du joueur.
func _get_pets_with_luck(egg_name: String) -> Array:
	var source_pets = _get_pets_from_egg(egg_name)
	var pets_copy = source_pets.duplicate(true)
	
	var low_tiers = pets_copy.filter(func(p): return p.rarity in low_tier_rarities)
	var high_tiers = pets_copy.filter(func(p): return not p.rarity in low_tier_rarities)
	
	# Augmente les chances des pets rares.
	var total_chance_boost = 0.0
	for pet in high_tiers:
		var boost = (pet.chance * total_luck_boost) - pet.chance
		total_chance_boost += boost
		pet.chance += boost
		
	# Diminue proportionnellement les chances des pets communs.
	var low_tier_chance_pool = low_tiers.reduce(func(sum, p): return sum + p.chance, 0.0)
	if low_tier_chance_pool > 0.001:
		for pet in low_tiers:
			var proportion_of_pool = pet.chance / low_tier_chance_pool
			var penalty = total_chance_boost * proportion_of_pool
			pet.chance = max(0.01, pet.chance - penalty) # Assure une chance minimale.
			
	# Renormalise toutes les chances pour que le total soit exactement 100.
	var final_pets = low_tiers + high_tiers
	var current_total = final_pets.reduce(func(sum, p): return sum + p.chance, 0.0)
	if current_total > 0:
		var scale_factor = 100.0 / current_total
		for pet in final_pets:
			pet.chance *= scale_factor
	else:
		return source_pets # Retourne la table originale en cas d'erreur.
		
	return final_pets


# ==============================================================================
# 3. FONCTIONS D'ANIMATION ET DE PLACEMENT
# ==============================================================================

# 🔹 Calcule et place les instances d'œufs dans une grille 3D centrée à l'écran.
func _place_eggs_on_grid(pets_data: Array, egg_model_scene: PackedScene):
	var count = pets_data.size()
	if count == 0: return

	# Calcule la taille de la grille et des cellules.
	var cols = ceil(sqrt(count))
	var rows = ceil(count / float(cols))
	var viewport_size = viewport_container.size
	var square_cell_size = min(viewport_size.x / cols, viewport_size.y / rows)
	
	# Calcule les dimensions de base d'un œuf pour le redimensionnement.
	var temp_egg = egg_model_scene.instantiate()
	var egg_original_max_dim = _get_total_aabb(temp_egg).get_longest_axis_size()
	temp_egg.queue_free()

	# Place chaque œuf.
	var plane_for_projection = Plane(Vector3.FORWARD, 0)
	for i in range(count):
		var grid_pos = Vector2i(i % int(cols), floor(i / cols))
		var screen_pos = _get_centered_screen_pos_for_grid(grid_pos, count, cols, square_cell_size)
		var world_pos = plane_for_projection.intersects_ray(
			camera.project_ray_origin(screen_pos),
			camera.project_ray_normal(screen_pos)
		)
		
		if world_pos != null:
			var egg_instance = egg_model_scene.instantiate()
			egg_grid_container.add_child(egg_instance)
			
			# Applique la bonne échelle.
			var target_egg_size = _get_3d_world_size_from_viewport(Vector2.ONE * square_cell_size).x
			var scale_factor = 1.0
			if egg_original_max_dim > 0.001:
				scale_factor = target_egg_size / egg_original_max_dim
			
			egg_instance.scale = Vector3.ONE * scale_factor * global_egg_scale_multiplier
			egg_instance.position = world_pos
			_set_node_render_layer(egg_instance, 1) # Couche 1: Gameplay 3D principal
			
			active_hatch_instances.append({"node": egg_instance, "pet_data": pets_data[i]})

# 🔹 Joue l'animation de secousse de l'œuf et de révélation du pet.
func _play_hatch_animation():
	if active_hatch_instances.is_empty(): return
	var safe_speed = max(DataManager.get_total_speed_boost(), 1.0)
	
	# Animation de secousse.
	var anim_duration = 0.5 / safe_speed
	var elapsed_time = 0.0
	var swing_amount = 0.3
	var swing_speed = 8.0
	while elapsed_time < anim_duration:
		elapsed_time += get_process_delta_time()
		var angle = sin(elapsed_time * swing_speed) * swing_amount
		for instance in active_hatch_instances:
			instance.node.rotation.y = angle
		await get_tree().process_frame
	
	# Révélation du pet.
	for instance in active_hatch_instances:
		var holder_node = instance.node
		var egg_model_node = holder_node.get_child(0)
		if egg_model_node: egg_model_node.visible = false
 
		var pet_data = instance.pet_data
		var pet_def = DataManager.PET_DEFINITIONS[pet_data.base_name]
 
		if pet_def and pet_def.model:
			var pet_instance = pet_def.model.instantiate()
			holder_node.add_child(pet_instance)
 
			pet_instance.scale = egg_model_node.scale
			pet_instance.position = Vector3.ZERO
			pet_instance.global_rotation = camera.global_rotation
			_set_node_render_layer(pet_instance, 1)
 
			_apply_visual_effect(pet_instance, pet_data.type)
 
			if pet_data.to_be_deleted:
				var cross_sprite = Sprite3D.new()
				cross_sprite.texture = RED_CROSS_TEXTURE
				cross_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				cross_sprite.no_depth_test = true
				cross_sprite.pixel_size = 0.01
				holder_node.add_child(cross_sprite)
 
	await get_tree().create_timer(0.25 / safe_speed).timeout


# ==============================================================================
# 4. FONCTIONS UTILITAIRES ET D'AIDE
# ==============================================================================

# 🔹 Ajoute les pets non supprimés à l'inventaire du joueur.
func _add_hatched_pets_to_inventory(pets_data: Array[Dictionary]):
	var pets_to_keep = pets_data.filter(func(p): return not p.to_be_deleted)
	for pet_data in pets_to_keep:
		DataManager.add_pet_to_inventory(pet_data.base_name, pet_data.type)

# 🔹 Nettoie les instances d'œufs/pets de la séquence précédente.
func _cleanup_previous_instances():
	for instance in active_hatch_instances:
		if is_instance_valid(instance.node):
			instance.node.queue_free()
	active_hatch_instances.clear()

# 🔹 Récupère la définition complète d'un œuf par son nom.
func _get_egg_definition(egg_name: String) -> Dictionary:
	for egg_def in DataManager.EGG_DEFINITIONS:
		if egg_def.name == egg_name:
			return egg_def
	return {}

# 🔹 Récupère la liste des pets contenus dans un œuf.
func _get_pets_from_egg(egg_name: String) -> Array:
	var result = []
	var egg_def = _get_egg_definition(egg_name)
	if not egg_def.is_empty():
		for pet_info_in_egg in egg_def.pets:
			var pet_name = pet_info_in_egg.name
			var full_pet_def = DataManager.PET_DEFINITIONS[pet_name].duplicate(true)
			full_pet_def.name = pet_name
			full_pet_def.chance = pet_info_in_egg.chance
			result.append(full_pet_def)
	return result

# 🔹 Applique un effet visuel (shader) à un modèle de pet.
func _apply_visual_effect(pet_node: Node3D, type_info: Dictionary):
	var mesh_instance = _find_mesh_recursively(pet_node)
	if not mesh_instance: return
	
	mesh_instance.material_overlay = null # Réinitialise
	
	if type_info.effect_type == "shader" and type_info.value is String and type_info.value.begins_with("res://"):
		var shader = load(type_info.value) as Shader
		if shader:
			var shader_material = ShaderMaterial.new()
			shader_material.shader = shader
			mesh_instance.material_overlay = shader_material

# 🔹 Calcule la position 2D centrée pour un item dans une grille.
func _get_centered_screen_pos_for_grid(grid_pos: Vector2i, total_items: int, cols: int, cell_size: float) -> Vector2:
	var rows = ceil(float(total_items) / cols)
	var total_grid_width = cols * cell_size
	var total_grid_height = rows * cell_size
	
	var x_offset = (viewport_container.size.x - total_grid_width) / 2.0
	var y_offset = (viewport_container.size.y - total_grid_height) / 2.0
	
	# Ajuste la dernière ligne si elle n'est pas complète.
	if grid_pos.y == int(rows) - 1:
		var items_in_last_row = total_items - (int(rows - 1) * int(cols))
		if items_in_last_row > 0:
			var last_row_width = items_in_last_row * cell_size
			x_offset = (viewport_container.size.x - last_row_width) / 2.0
	
	var screen_pos = Vector2(x_offset + (grid_pos.x * cell_size), y_offset + (grid_pos.y * cell_size))
	return screen_pos + (Vector2.ONE * cell_size / 2.0)

# 🔹 Calcule la taille d'un objet dans le monde 3D à partir de sa taille en pixels à l'écran.
func _get_3d_world_size_from_viewport(size_in_pixels: Vector2) -> Vector2:
	var plane = Plane(Vector3.FORWARD, 0)
	var pos0_3d = plane.intersects_ray(camera.project_ray_origin(Vector2.ZERO), camera.project_ray_normal(Vector2.ZERO))
	var pos_size_3d = plane.intersects_ray(camera.project_ray_origin(size_in_pixels), camera.project_ray_normal(size_in_pixels))
	if pos0_3d != null and pos_size_3d != null:
		return Vector2(abs(pos_size_3d.x - pos0_3d.x), abs(pos_size_3d.y - pos0_3d.y))
	return Vector2.ONE

# 🔹 Trouve récursivement le premier nœud MeshInstance3D dans une hiérarchie.
func _find_mesh_recursively(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D: return node
	for child in node.get_children():
		var mesh = _find_mesh_recursively(child)
		if mesh: return mesh
	return null

# 🔹 Calcule la AABB (boîte englobante) totale pour un nœud 3D et ses enfants.
func _get_total_aabb(node: Node3D) -> AABB:
	var total_aabb = AABB()
	if node is VisualInstance3D: total_aabb = node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var child_aabb = _get_total_aabb(child)
			total_aabb = total_aabb.merge(child.transform * child_aabb)
	return total_aabb

# 🔹 Applique une couche de rendu à tous les meshes d'un nœud et de ses enfants.
func _set_node_render_layer(node: Node, layer: int):
	if node is MeshInstance3D:
		node.layers = 1 << (layer - 1) # Godot attend un bitmask
	for child in node.get_children():
		_set_node_render_layer(child, layer)

# 🔹 Convertit les 8 premiers octets d'un PackedByteArray en un entier.
func _bytes_to_int(bytes: PackedByteArray) -> int:
	var integer: int = 0
	for i in min(bytes.size(), 8):
		integer = (integer << 8) | bytes[i]
	return integer
