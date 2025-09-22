# IndexSlot.gd
extends PanelContainer

@onready var pet_name_label: Label = %PetNameLabel
@onready var preview_viewport_container: SubViewportContainer = %PetPreview


# 🔹 Configure ce slot avec les données d'un pet pour l'Index.
func setup(pet_name: String, is_discovered: bool):
	# On attend la fin de la frame pour être sûr que tout est prêt.
	# C'est une sécurité non-bloquante.
	await get_tree().process_frame

	# On navigue dans l'arbre pour trouver le support 3D.
	var pet_holder: Node3D
	var preview_scene = preview_viewport_container.get_child(0).get_child(0)
	if preview_scene and preview_scene.has_node("ObjectHolder"):
		pet_holder = preview_scene.get_node("ObjectHolder")
	else:
		printerr("ERREUR dans IndexSlot: ObjectHolder non trouvé.")
		return
	
	# On vide le support.
	for child in pet_holder.get_children():
		child.queue_free()
	
	if is_discovered:
		# Le pet est découvert.
		self.modulate = Color.WHITE
		pet_name_label.text = pet_name
		
		var pet_def = DataManager.pet_definitions[pet_name]
		var model = pet_def["model"].instantiate()
		pet_holder.add_child(model)
		
		var visual_node = find_mesh_recursively(model)
		if visual_node:
			visual_node.layers = 4 # Couche 3 pour les previews.
	else:
		# Le pet n'est pas découvert.
		self.modulate = Color.WHITE
		pet_name_label.text = "???"
		
		# On charge un modèle de "silhouette" ou on le laisse vide.
		# Pour l'instant, on va juste le teinter.
		var pet_def = DataManager.pet_definitions[pet_name]
		var model = pet_def["model"].instantiate()
		pet_holder.add_child(model)
		
		var visual_node = find_mesh_recursively(model)
		if visual_node:
			visual_node.layers = 4
			
			# On applique un matériau noir pour faire une silhouette.
			var silhouette_material = StandardMaterial3D.new()
			silhouette_material.albedo_color = Color.BLACK
			visual_node.material_override = silhouette_material

func find_mesh_recursively(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D: return node
	for child in node.get_children():
		var mesh = find_mesh_recursively(child)
		if mesh: return mesh
	return null
