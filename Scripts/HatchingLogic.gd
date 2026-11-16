# HatchingLogic.gd
extends Node

# --- Signaux ---
signal animation_started
signal animation_finished

# --- Constantes ---
const PetVisuals = preload("res://Scripts/PetVisuals.gd")
const RED_CROSS_TEXTURE = preload("res://Assets/UI/red_cross.png")
const POP_SCALE_BY_ORDER = [1.0, 1.30, 1.55, 1.80, 2.10]
const SHAKE_DURATION = 0.5
const REVEAL_DURATION = 0.25
const END_PAUSE_DURATION = 0.25
const POP_GROW_DURATION = 0.18
const POP_SHRINK_DURATION = 0.22
const NAME_LABEL_FONT_SIZE = 48
const NAME_LABEL_OUTLINE_SIZE = 14
const NAME_LABEL_PIXELS_PER_EGG = 300.0
const NAME_LABEL_DROP_RATIO = 0.72

# --- Paramètres de Jeu ---
@export var base_hatch_max: int = 12
@export var global_egg_scale_multiplier: float = 0.5

# --- État Interne ---
var NumberOfEggMax: int = 0
var is_hatching: bool = false
var auto_hatch_enabled: bool = false
var active_hatch_instances: Array[Dictionary] = []
var _egg_local_size: float = 1.0

# --- Références Externes (fournies par main.gd) ---
var camera: Camera3D
var egg_grid_container: Node3D
var viewport_container: Viewport


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Rend la logique d'éclosion sensible à la pause du jeu.
func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE


# --- Orchestration de l'Éclosion ---

# 🔹 Reçoit une demande d'éclosion (count = -1 pour basculer l'auto-hatch).
func on_hatch_requested(egg_name: String, count: int):
	if count == -1:
		_toggle_auto_hatch(egg_name)
	else:
		_start_hatch_sequence(egg_name, count, false)

# 🔹 Active ou désactive l'auto-hatch pour un œuf.
func _toggle_auto_hatch(egg_name: String):
	auto_hatch_enabled = not auto_hatch_enabled
	if auto_hatch_enabled:
		_auto_hatch_loop(egg_name)

# 🔹 Enchaîne les éclosions tant que l'auto-hatch est actif, puis rend la main à l'interface.
func _auto_hatch_loop(egg_name: String):
	while auto_hatch_enabled:
		if not is_hatching and not get_tree().paused:
			var success = await _start_hatch_sequence(egg_name, NumberOfEggMax, true)
			if not success:
				auto_hatch_enabled = false
		if auto_hatch_enabled:
			await get_tree().process_frame
	animation_finished.emit()

# 🔹 Demande une éclosion au backend, puis joue l'animation des pets obtenus.
func _start_hatch_sequence(egg_name: String, requested_count: int, from_auto_hatch: bool) -> bool:
	if is_hatching:
		return false
	is_hatching = true
	var result = await Backend.hatch(egg_name, requested_count)
	if not result.ok:
		is_hatching = false
		return false
	animation_started.emit()
	_cleanup_previous_instances()
	_place_eggs_on_grid(result.pets, GameConfig.get_egg_definition(egg_name).model)
	await _play_hatch_animation()
	await _wait(END_PAUSE_DURATION / _get_safe_speed())
	_cleanup_previous_instances()
	is_hatching = false
	if not from_auto_hatch:
		animation_finished.emit()
	return true


# --- Animation et Placement ---

# 🔹 Place un œuf 3D par pet tiré, en grille centrée devant la caméra.
func _place_eggs_on_grid(pets_data: Array, egg_model_scene: PackedScene):
	var count = pets_data.size()
	if count == 0:
		return
	var view_size = _get_view_size()
	var cols = int(ceil(sqrt(count)))
	var rows = int(ceil(count / float(cols)))
	var cell_size = min(view_size.x / cols, view_size.y / rows)
	var temp_egg = egg_model_scene.instantiate()
	var egg_original_max_dim = _get_total_aabb(temp_egg).get_longest_axis_size()
	temp_egg.free()
	var target_size = _get_3d_world_size_from_viewport(Vector2.ONE * cell_size).x
	var scale_factor = 1.0
	_egg_local_size = 1.0
	if egg_original_max_dim > 0.001:
		scale_factor = target_size / egg_original_max_dim
		_egg_local_size = egg_original_max_dim
	var plane = Plane(Vector3.FORWARD, 0)
	for i in range(count):
		var grid_pos = Vector2i(i % cols, floori(i / float(cols)))
		var screen_pos = _get_centered_screen_pos_for_grid(grid_pos, count, cols, cell_size)
		var world_pos = plane.intersects_ray(camera.project_ray_origin(screen_pos), camera.project_ray_normal(screen_pos))
		if world_pos == null:
			continue
		var egg_instance = egg_model_scene.instantiate()
		egg_grid_container.add_child(egg_instance)
		egg_instance.scale = Vector3.ONE * scale_factor * global_egg_scale_multiplier
		egg_instance.position = world_pos
		PetVisuals.set_render_layer(egg_instance, PetVisuals.RENDER_LAYER_WORLD)
		active_hatch_instances.append({"node": egg_instance, "pet_data": pets_data[i]})

# 🔹 Joue la secousse des œufs puis révèle les pets.
func _play_hatch_animation():
	if active_hatch_instances.is_empty():
		return
	var safe_speed = _get_safe_speed()
	var shake_duration = SHAKE_DURATION / safe_speed
	var elapsed_time = 0.0
	while elapsed_time < shake_duration:
		if not get_tree().paused:
			elapsed_time += get_process_delta_time()
			var angle = sin(elapsed_time * 8.0) * 0.3
			for instance in active_hatch_instances:
				if is_instance_valid(instance.node):
					instance.node.rotation.y = angle
		await get_tree().process_frame
	for instance in active_hatch_instances:
		if is_instance_valid(instance.node):
			_reveal_pet(instance.node, instance.pet_data, safe_speed)
	await _wait(REVEAL_DURATION / safe_speed)

# 🔹 Remplace un œuf par le modèle du pet tiré, avec son effet et sa croix d'auto-delete.
func _reveal_pet(holder_node: Node3D, pet_data: Dictionary, safe_speed: float):
	var pet_scale = Vector3.ONE
	if holder_node.get_child_count() > 0:
		var egg_model_node = holder_node.get_child(0)
		egg_model_node.visible = false
		pet_scale = egg_model_node.scale
	var pet_instance = PetVisuals.create_pet_model(pet_data.base_name, pet_data.type, PetVisuals.RENDER_LAYER_WORLD)
	holder_node.add_child(pet_instance)
	pet_instance.scale = pet_scale
	pet_instance.position = Vector3.ZERO
	pet_instance.global_rotation = camera.global_rotation
	_add_name_label(holder_node, pet_data)
	if pet_data.type.order > 0:
		_play_pop_animation(pet_instance, pet_data.type.order, safe_speed)
	if pet_data.get("to_be_deleted", false):
		var cross_sprite = Sprite3D.new()
		cross_sprite.texture = RED_CROSS_TEXTURE
		cross_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		cross_sprite.no_depth_test = true
		cross_sprite.pixel_size = 0.01
		holder_node.add_child(cross_sprite)

# 🔹 Affiche sous le pet révélé son nom suivi de son type, ex. « Fox (Golden) ».
func _add_name_label(holder_node: Node3D, pet_data: Dictionary):
	var name_label = Label3D.new()
	name_label.text = "%s (%s)" % [pet_data.base_name, pet_data.type.name]
	name_label.font_size = NAME_LABEL_FONT_SIZE
	name_label.outline_size = NAME_LABEL_OUTLINE_SIZE
	name_label.pixel_size = _egg_local_size / NAME_LABEL_PIXELS_PER_EGG
	name_label.no_depth_test = true
	name_label.render_priority = 1
	name_label.outline_render_priority = 0
	holder_node.add_child(name_label)
	name_label.position = Vector3(0, -_egg_local_size * NAME_LABEL_DROP_RATIO, 0)
	name_label.global_rotation = camera.global_rotation

# 🔹 Joue un "pop" dont l'intensité dépend de la rareté du type et la durée de la vitesse d'éclosion.
func _play_pop_animation(pet_node: Node3D, type_order: int, safe_speed: float):
	var base_scale = pet_node.scale
	var peak_scale = base_scale * POP_SCALE_BY_ORDER[clampi(type_order, 0, POP_SCALE_BY_ORDER.size() - 1)]
	var grow_time = POP_GROW_DURATION / safe_speed
	var shrink_time = POP_SHRINK_DURATION / safe_speed
	var scale_tween = create_tween()
	scale_tween.tween_property(pet_node, "scale", peak_scale, grow_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	scale_tween.tween_property(pet_node, "scale", base_scale, shrink_time).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_ELASTIC)
	if type_order >= 2:
		var spin_tween = create_tween()
		spin_tween.tween_property(pet_node, "rotation:y", pet_node.rotation.y + TAU, grow_time + shrink_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)


# --- Utilitaires ---

# 🔹 Retourne la vitesse d'éclosion, jamais inférieure à 1.
func _get_safe_speed() -> float:
	return max(DataManager.get_total_speed_boost(), 1.0)

# 🔹 Attend une durée en secondes, en respectant la pause du jeu.
func _wait(duration: float):
	await get_tree().create_timer(duration, false).timeout

# 🔹 Retourne la taille du viewport dans les coordonnées utilisées par la caméra.
func _get_view_size() -> Vector2:
	return viewport_container.get_visible_rect().size

# 🔹 Supprime les œufs et pets 3D de l'éclosion précédente.
func _cleanup_previous_instances():
	for instance in active_hatch_instances:
		if is_instance_valid(instance.node):
			instance.node.queue_free()
	active_hatch_instances.clear()

# 🔹 Calcule la position écran du centre d'une cellule, avec la dernière ligne centrée.
func _get_centered_screen_pos_for_grid(grid_pos: Vector2i, total_items: int, cols: int, cell_size: float) -> Vector2:
	var view_size = _get_view_size()
	var rows = int(ceil(total_items / float(cols)))
	var items_in_row = cols
	if grid_pos.y == rows - 1:
		items_in_row = total_items - (rows - 1) * cols
	var x_offset = (view_size.x - items_in_row * cell_size) / 2.0
	var y_offset = (view_size.y - rows * cell_size) / 2.0
	return Vector2(x_offset + grid_pos.x * cell_size, y_offset + grid_pos.y * cell_size) + Vector2.ONE * cell_size / 2.0

# 🔹 Convertit une taille en pixels écran en taille dans le monde 3D.
func _get_3d_world_size_from_viewport(size_in_pixels: Vector2) -> Vector2:
	var plane = Plane(Vector3.FORWARD, 0)
	var pos0 = plane.intersects_ray(camera.project_ray_origin(Vector2.ZERO), camera.project_ray_normal(Vector2.ZERO))
	var pos1 = plane.intersects_ray(camera.project_ray_origin(size_in_pixels), camera.project_ray_normal(size_in_pixels))
	if pos0 != null and pos1 != null:
		return Vector2(abs(pos1.x - pos0.x), abs(pos1.y - pos0.y))
	return Vector2.ONE

# 🔹 Calcule la boîte englobante d'un nœud 3D et de tous ses enfants.
func _get_total_aabb(node: Node3D) -> AABB:
	var total_aabb = AABB()
	if node is VisualInstance3D:
		total_aabb = node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			total_aabb = total_aabb.merge(child.transform * _get_total_aabb(child))
	return total_aabb
