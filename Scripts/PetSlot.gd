# PetSlot.gd
extends Button

# --- Constantes ---
const EQUIPPED_STYLE = preload("res://style/equipped_style.tres")
const RENDER_LAYER_PREVIEW = 3 # Couche de rendu pour les previews de l'UI

# --- Références aux Nœuds ---
# On accède directement à la scène de preview grâce à son nom unique.
@onready var preview_scene: Node3D = %PetPreview3D


# --- Méthodes Publiques ---

# 🔹 Configure l'apparence du slot (modèle 3D, effet, bordure d'équipement) pour un pet donné.
func setup(pet_instance: Dictionary):
	# Pas besoin d'attendre ici, les @onready garantissent que les nœuds sont disponibles.
	
	# Configure l'infobulle.
	self.tooltip_text = "%s (%s)" % [pet_instance.base_name, pet_instance.type.name]
	
	# Récupère le conteneur du modèle 3D à l'intérieur de la scène de preview.
	var object_holder: Node3D = preview_scene.get_node("ObjectHolder")
	
	# Nettoie l'ancien modèle.
	for child in object_holder.get_children():
		child.queue_free()
	
	# Instancie et configure le nouveau modèle.
	var pet_base_name = pet_instance.base_name
	if DataManager.PET_DEFINITIONS.has(pet_base_name):
		var pet_def = DataManager.PET_DEFINITIONS[pet_base_name]
		var model = pet_def.model.instantiate()
		object_holder.add_child(model)
		
		_apply_slot_effect(model, pet_instance.type)
		_set_model_render_layer(model, RENDER_LAYER_PREVIEW)
	
	# Met à jour la bordure visuelle si le pet est équipé.
	_update_equipped_style(pet_instance.unique_id)


# --- Méthodes Internes ---

# 🔹 Applique une bordure visuelle au slot si le pet est dans l'équipe.
func _update_equipped_style(pet_id: int):
	var is_equipped = pet_id in DataManager.equipped_pets
	if is_equipped:
		add_theme_stylebox_override("normal", EQUIPPED_STYLE)
	else:
		# Assure-toi que le style est bien retiré s'il n'est pas équipé.
		if get_theme_stylebox("normal") == EQUIPPED_STYLE:
			remove_theme_stylebox_override("normal")

# 🔹 Applique un effet visuel (shader) au modèle du pet.
func _apply_slot_effect(pet_node: Node3D, type_info: Dictionary):
	var mesh_instance = _find_mesh_recursively(pet_node)
	if not mesh_instance: return
	
	mesh_instance.material_overlay = null # Réinitialise
	
	if type_info.effect_type == "shader" and type_info.value is String and type_info.value.begins_with("res://"):
		var shader = load(type_info.value) as Shader
		if shader:
			var shader_material = ShaderMaterial.new()
			shader_material.shader = shader
			mesh_instance.material_overlay = shader_material

# 🔹 Applique une couche de rendu à tous les meshes d'un nœud et de ses enfants.
func _set_model_render_layer(node: Node, layer_number: int):
	var layer_mask = 1 << (layer_number - 1)
	
	if node is MeshInstance3D:
		node.layers = layer_mask
	for child in node.get_children():
		_set_model_render_layer(child, layer_number)

# 🔹 Trouve récursivement le premier nœud MeshInstance3D dans une hiérarchie.
func _find_mesh_recursively(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var mesh = _find_mesh_recursively(child)
		if mesh:
			return mesh
	return null
