# HatchingLogic.gd
extends Node

# 🔹 Paramètres de jeu, configurables depuis l'inspecteur
@export var NumberOfEggMax = 12
@export var Luck = 1.0
@export var Speed = 1.0
@export var global_egg_scale_multiplier = 0.65
@export var low_tier_rarities: Array[String] = ["Common", "Uncommon", "Rare", "Legendary"]

# 🔹 Variables internes
var IsHatching = false
var AutoHatch = false
var rng = RandomNumberGenerator.new()
var active_hatch_instances = []

# 🔹 Références aux nœuds 3D, qui seront fournies par le script Main.gd
var camera: Camera3D
var egg_grid_container: Node3D
var viewport_container: Viewport

# 🔹 Signaux pour communiquer avec le script Main.gd
signal animation_started
signal animation_finished

# 🔹 Initialisation
func _ready():
	var crypto = Crypto.new()
	var random_bytes = crypto.generate_random_bytes(8)
	rng.seed = bytes_to_int(random_bytes)

# 🔹 Point d'entrée, appelé par l'interface via Main.gd
func on_hatch_requested(egg_name: String, count: int):
	if count == -1: # Le code -1 est utilisé pour basculer l'auto-hatch
		AutoHatch = !AutoHatch
		if AutoHatch:
			auto_hatch_loop(egg_name)
		else:
			print("🛑 Auto-Hatch désactivé.")
	else:
		hatch_eggs(egg_name, count)

# 🔹 Boucle pour l'éclosion automatique
func auto_hatch_loop(egg_name: String):
	print("🚀 Auto-Hatch activé pour %s" % egg_name)
	while AutoHatch:
		if not IsHatching:
			await hatch_eggs(egg_name, NumberOfEggMax)
		else:
			await get_tree().process_frame

# 🔹 Fonction principale qui orchestre une seule séquence d'éclosion
func hatch_eggs(egg_name: String, count: int):
	if IsHatching: return
	IsHatching = true
	animation_started.emit() # Informe le Main.gd de montrer l'écran d'animation
	await get_tree().process_frame
	
	for instance in active_hatch_instances:
		if is_instance_valid(instance.node): instance.node.queue_free()
	active_hatch_instances.clear()
	
	var lucky_pets_table = get_pets_with_luck(egg_name)
	var pets_to_hatch = []
	for i in range(count):
		pets_to_hatch.append(hatch_pet(lucky_pets_table))
 
	place_eggs_on_grid(pets_to_hatch, egg_name)
	await play_simultaneous_hatch_animation()
	
	for pet_data in pets_to_hatch:
		DataManager.add_pet_to_inventory(pet_data["base_name"], pet_data["type"])
	
	var safe_speed = max(Speed, 1.0)
	await get_tree().create_timer(1.5 / safe_speed).timeout
	
	for instance in active_hatch_instances:
		if is_instance_valid(instance.node): instance.node.queue_free()
	active_hatch_instances.clear()
	
	IsHatching = false
	if not AutoHatch:
		animation_finished.emit() # Informe le Main.gd de revenir à l'écran de sélection

# --- Fonctions de Tirage ---

# 🔹 Récupère la liste des pets possibles pour un œuf donné
func get_pets_from_egg(egg_name: String) -> Array:
	var result = []
	for egg_def in DataManager.egg_definitions:
		if egg_def["name"] == egg_name:
			for pet_name in egg_def["pets"]:
				var pet_def = DataManager.pet_definitions[pet_name].duplicate(true)
				pet_def["name"] = pet_name # S'assure que le nom est inclus
				result.append(pet_def)
			return result
	return []

# 🔹 Calcule une table de chances temporaire, modifiée par 'Luck'
func get_pets_with_luck(egg_name: String) -> Array:
	var source_pets = get_pets_from_egg(egg_name)
	var pets_copy = source_pets.duplicate(true)
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
	for pet in final_pets: current_total += pet["chance"]
	if current_total > 0:
		var scale_factor = 100.0 / current_total
		for pet in final_pets:
			pet["chance"] *= scale_factor
	else:
		return source_pets
	return final_pets
	
# 🔹 Tire UN pet ET son type, en utilisant une table de chances pré-calculée
func hatch_pet(pets_to_roll: Array) -> Dictionary:
	var roll = rng.randf_range(0.0, 100.0)
	var cumulative = 0.0
	for pet_data in pets_to_roll:
		cumulative += pet_data["chance"]
		if roll <= cumulative:
			var final_pet_data = pet_data.duplicate()
			final_pet_data["base_name"] = pet_data["name"]
			final_pet_data["type"] = roll_pet_type()
			return final_pet_data
	var fallback_pet = pets_to_roll[0].duplicate()
	fallback_pet["base_name"] = pets_to_roll[0]["name"]
	fallback_pet["type"] = DataManager.pet_types.back()
	return fallback_pet
	
# 🔹 Tire un "type" de pet (Golden, etc.) en utilisant un système de probabilités cumulées
func roll_pet_type() -> Dictionary:
	var roll = rng.randf_range(0.0, 100.0)
	var cumulative = 0.0
	for type_data in DataManager.pet_types:
		cumulative += type_data["chance"]
		if roll <= cumulative: return type_data
	return DataManager.pet_types[0]

# --- Fonctions d'Animation ---

# 🔹 Calcule et place les instances d'œufs dans une grille centrée à l'écran
func place_eggs_on_grid(pets_data: Array, egg_name: String):
	var count = pets_data.size()
	if count == 0: return
	
	var egg_model_to_use = DataManager.egg_definitions[0]["model"]
	for egg_def in DataManager.egg_definitions:
		if egg_def["name"] == egg_name:
			egg_model_to_use = egg_def["model"]
			break
			
	var temp_egg = egg_model_to_use.instantiate()
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
			var egg_instance = egg_model_to_use.instantiate()
			
			var visual_node = find_mesh_recursively(egg_instance)
			if visual_node:
				visual_node.layers = 1
			
			var target_egg_size = get_3d_world_size_from_viewport(Vector2(square_cell_size, square_cell_size)).x
			var correct_scale_factor = 1.0
			if egg_original_max_dim > 0.001:
				correct_scale_factor = target_egg_size / egg_original_max_dim
			correct_scale_factor *= global_egg_scale_multiplier
			egg_instance.scale = Vector3.ONE * correct_scale_factor
			egg_instance.position = world_pos
			egg_grid_container.add_child(egg_instance)
			active_hatch_instances.append({"node": egg_instance, "pet_data": pets_data[i]})

# 🔹 Joue la cinématique de balancement et de révélation
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
		var pet_holder_node = instance.node
		
		var egg_model_node = pet_holder_node.get_child(0)
		if egg_model_node:
			egg_model_node.visible = false
		
		var pet_data = instance.pet_data
		var pet_def = DataManager.pet_definitions[pet_data["base_name"]]
		
		if pet_def and pet_def.model:
			var pet_instance = pet_def.model.instantiate()
			pet_holder_node.add_child(pet_instance)
			
			pet_instance.scale = egg_model_node.scale
			
			pet_instance.position = Vector3.ZERO
			pet_instance.global_rotation = camera.global_rotation
			
			var visual_node = find_mesh_recursively(pet_instance)
			if visual_node:
				visual_node.layers = 1
			
			apply_visual_effect(pet_instance, pet_data["type"])
			
	await get_tree().create_timer(0.5 / safe_speed).timeout

# --- Fonctions Utilitaires ---

func apply_visual_effect(pet_node: Node3D, type_info: Dictionary):
	var mesh_instance = find_mesh_recursively(pet_node)
	if not mesh_instance: return
	mesh_instance.material_override = null
	mesh_instance.material_overlay = null
	var effect_type = type_info["effect_type"]
	var effect_value = type_info["value"]
	
	match effect_type:
		"none": pass
#		"color":
#			for i in range(mesh_instance.get_surface_override_material_count()):
#				var original_material = mesh_instance.get_active_material(i)
#				var new_material = original_material.duplicate(true) if original_material else StandardMaterial3D.new()
#				if new_material is StandardMaterial3D:
#					new_material.albedo_color = effect_value
#					mesh_instance.set_surface_override_material(i, new_material)
		"shader":
			if not "res://" in effect_value: return
			var shader = load(effect_value) as Shader
			if shader:
				var shader_material = ShaderMaterial.new()
				shader_material.shader = shader
				mesh_instance.material_overlay = shader_material

func find_mesh_recursively(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D: return node
	for child in node.get_children():
		var mesh = find_mesh_recursively(child)
		if mesh: return mesh
	return null

func get_total_aabb(node: Node3D) -> AABB:
	var total_aabb = AABB()
	if node is VisualInstance3D: total_aabb = node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var child_aabb = get_total_aabb(child)
			child_aabb = child.transform * child_aabb
			total_aabb = total_aabb.merge(child_aabb)
	return total_aabb

func bytes_to_int(bytes: PackedByteArray) -> int:
	var integer: int = 0
	for i in min(bytes.size(), 8): integer = (integer << 8) | bytes[i]
	return integer
	
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
