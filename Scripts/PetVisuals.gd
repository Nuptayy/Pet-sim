# PetVisuals.gd
extends RefCounted

# --- Constantes ---
const RENDER_LAYER_WORLD = 1
const RENDER_LAYER_EGG_PREVIEW = 2
const RENDER_LAYER_PET_PREVIEW = 3

# --- État Partagé ---
static var _effect_materials: Dictionary = {}
static var _silhouette_material: StandardMaterial3D


# --- Création de Modèles ---

# 🔹 Instancie le modèle 3D d'un pet avec l'effet de son type, sur la couche de rendu donnée.
static func create_pet_model(pet_base_name: String, type_info: Dictionary, render_layer: int) -> Node3D:
	var model: Node3D = GameConfig.PET_DEFINITIONS[pet_base_name].model.instantiate()
	set_render_layer(model, render_layer)
	apply_type_effect(model, type_info)
	return model

# 🔹 Retire immédiatement de l'arbre tous les enfants d'un nœud, puis les libère.
static func clear_children(parent: Node):
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


# --- Effets Visuels ---

# 🔹 Applique le shader du type de pet en surcouche sur tous les meshes du modèle.
static func apply_type_effect(model: Node, type_info: Dictionary):
	if type_info.is_empty() or type_info.get("effect_type", "none") != "shader":
		return
	var material = _get_effect_material(type_info.value)
	if material:
		_set_overlay_recursive(model, material)

# 🔹 Rend le modèle entièrement noir pour figurer un pet non découvert.
static func apply_silhouette(model: Node):
	if _silhouette_material == null:
		_silhouette_material = StandardMaterial3D.new()
		_silhouette_material.albedo_color = Color.BLACK
		_silhouette_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_set_override_recursive(model, _silhouette_material)

# 🔹 Place tous les meshes d'un nœud sur une couche de rendu donnée.
static func set_render_layer(node: Node, layer_number: int):
	if node is MeshInstance3D:
		node.layers = 1 << (layer_number - 1)
	for child in node.get_children():
		set_render_layer(child, layer_number)


# --- Méthodes Internes ---

# 🔹 Retourne le matériau partagé d'un shader d'effet, créé au premier appel.
static func _get_effect_material(shader_path) -> ShaderMaterial:
	if not (shader_path is String and shader_path.begins_with("res://")):
		return null
	if not _effect_materials.has(shader_path):
		var shader = load(shader_path) as Shader
		if shader == null:
			return null
		var material = ShaderMaterial.new()
		material.shader = shader
		_effect_materials[shader_path] = material
	return _effect_materials[shader_path]

# 🔹 Pose récursivement un matériau de surcouche sur chaque mesh.
static func _set_overlay_recursive(node: Node, material: Material):
	if node is MeshInstance3D:
		node.material_overlay = material
	for child in node.get_children():
		_set_overlay_recursive(child, material)

# 🔹 Remplace récursivement le matériau de chaque mesh.
static func _set_override_recursive(node: Node, material: Material):
	if node is MeshInstance3D:
		node.material_override = material
	for child in node.get_children():
		_set_override_recursive(child, material)
