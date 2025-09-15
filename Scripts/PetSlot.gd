# PetSlot.gd
extends Button

# 🔹 Configure ce slot avec les données d'un pet.
# Cette fonction est maintenant la seule responsable de l'initialisation.
func setup(pet_instance: Dictionary):
	# On s'assure que les enfants du bouton sont prêts avant de continuer.
	if not has_node("SubViewportContainer"):
		# Si le SubViewportContainer n'est pas encore là, on attend la prochaine frame.
		# C'est une sécurité pour éviter les crashs.
		await get_tree().process_frame
		if not has_node("SubViewportContainer"):
			printerr("ERREUR CRITIQUE dans PetSlot: SubViewportContainer est manquant.")
			return

	var sub_viewport = get_node("SubViewportContainer").get_child(0)
	if sub_viewport.get_child_count() == 0:
		await get_tree().process_frame
		if sub_viewport.get_child_count() == 0:
			printerr("ERREUR CRITIQUE dans PetSlot: La scène de preview est manquante dans le SubViewport.")
			return

	var preview_scene = sub_viewport.get_child(0)
	var pet_holder: Node3D = preview_scene.get_node("ObjectHolder")
	
	if not is_instance_valid(pet_holder):
		printerr("ERREUR CRITIQUE dans PetSlot: ObjectHolder non trouvé.")
		return
		
	# À partir d'ici, on est sûr que tout existe.
	
	# Vide le support.
	for child in pet_holder.get_children():
		child.queue_free()
		
	# Charge la définition du pet.
	var pet_base_name = pet_instance["base_name"]
	if DataManager.pet_definitions.has(pet_base_name):
		var pet_def = DataManager.pet_definitions[pet_base_name]
		
		# Instancie et ajoute le modèle.
		var model = pet_def["model"].instantiate()
		pet_holder.add_child(model)
		
		# Assigne le modèle à la bonne couche.
		var visual_node = find_mesh_recursively(model)
		if visual_node:
			visual_node.layers = 4 # Couche 3 pour la preview de pet.
		
		# Applique les effets.
		apply_slot_effect(model, pet_instance["type"])
	self.tooltip_text = pet_instance["base_name"] + " (" + pet_instance["type"]["name"] + ")"

# 🔹 Applique l'effet visuel au modèle de pet dans le slot.
func apply_slot_effect(pet_node: Node3D, type_info: Dictionary):
	var mesh_instance = find_mesh_recursively(pet_node)
	if not mesh_instance: return
		
	var effect_type = type_info["effect_type"]
	var effect_value = type_info["value"]
	
	match effect_type:
		"none": pass
		"color":
			for i in range(mesh_instance.get_surface_override_material_count()):
				var original_material = mesh_instance.get_surface_override_material(i)
				var new_material = original_material.duplicate() if original_material else StandardMaterial3D.new()
				if new_material is StandardMaterial3D:
					new_material.albedo_color = effect_value
					mesh_instance.set_surface_override_material(i, new_material)
		"shader":
			if not "res://" in effect_value: return
			var shader = load(effect_value) as Shader
			if shader:
				var shader_material = ShaderMaterial.new()
				shader_material.shader = shader
				for i in range(mesh_instance.get_surface_override_material_count()):
					mesh_instance.set_surface_override_material(i, shader_material)

# 🔹 Trouve la première instance de MeshInstance3D dans un nœud et ses enfants.
func find_mesh_recursively(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D: return node
	for child in node.get_children():
		var mesh = find_mesh_recursively(child)
		if mesh: return mesh
	return null
