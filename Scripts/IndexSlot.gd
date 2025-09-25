# IndexSlot.gd
extends PanelContainer

# --- Constantes ---
const RENDER_LAYER_PREVIEW = 3 # Couche de rendu pour les previews de l'UI

# --- Références aux Nœuds ---
@onready var pet_name_label: Label = %PetNameLabel
@onready var preview_viewport_container: SubViewportContainer = %PetPreview


# --- Méthodes Publiques ---

# 🔹 Configure l'apparence du slot en fonction d'un pet et de son statut "découvert".
func setup(pet_name: String, is_discovered: bool):
	# Attend que les nœuds enfants (SubViewport, etc.) soient prêts.
	await get_tree().process_frame

	# Récupère le conteneur pour le modèle 3D.
	var preview_scene = preview_viewport_container.get_child(0).get_child(0)
	var object_holder: Node3D = preview_scene.get_node_or_null("ObjectHolder")
	
	if not is_instance_valid(object_holder):
		printerr("ERREUR dans IndexSlot: 'ObjectHolder' non trouvé dans la scène de preview.")
		return
	
	# Nettoie l'ancien modèle.
	for child in object_holder.get_children():
		child.queue_free()

	# Instancie le modèle du pet.
	var pet_def = DataManager.PET_DEFINITIONS[pet_name]
	var model = pet_def.model.instantiate()
	object_holder.add_child(model)
	
	# Applique les styles "découvert" ou "non découvert".
	if is_discovered:
		pet_name_label.text = pet_name
		# Affiche le modèle normalement.
		_set_model_render_layer(model, RENDER_LAYER_PREVIEW)
	else:
		pet_name_label.text = "???"
		# Applique un effet de silhouette.
		_apply_silhouette_effect(model)
		_set_model_render_layer(model, RENDER_LAYER_PREVIEW)


# --- Méthodes Internes ---

# 🔹 Applique un matériau noir au modèle pour créer un effet de silhouette.
func _apply_silhouette_effect(model_node: Node3D):
	var visual_node = _find_mesh_recursively(model_node)
	if visual_node:
		var silhouette_material = StandardMaterial3D.new()
		silhouette_material.albedo_color = Color.BLACK
		visual_node.material_override = silhouette_material

# 🔹 Applique une couche de rendu à tous les meshes d'un nœud et de ses enfants.
func _set_model_render_layer(node: Node, layer_number: int):
	# Godot utilise un bitmask pour les layers, donc 1 -> 1, 2 -> 2, 3 -> 4, 4 -> 8, etc.
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
