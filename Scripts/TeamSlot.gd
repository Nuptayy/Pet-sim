# TeamSlot.gd
extends Button

signal unequip_requested(pet_id)

const EQUIPPED_STYLE = preload("res://style/equipped_style.tres")
const RENDER_LAYER_PREVIEW = 3

@onready var preview_scene: Node3D = %PetPreview3D

var _pet_instance

# 🔹 Configure le slot avec les données d'un pet ou le met en état "vide".
func setup(pet_instance_or_null):
	_pet_instance = pet_instance_or_null
	
	tooltip_text = ""
	
	var pet_holder: Node3D = preview_scene.get_node("ObjectHolder")
	for child in pet_holder.get_children():
		child.queue_free()

	if _pet_instance is Dictionary:
		disabled = false
		tooltip_text = "%s (%s)" % [_pet_instance.base_name, _pet_instance.type.name]
		add_theme_stylebox_override("normal", EQUIPPED_STYLE)
		
		var pet_def = DataManager.PET_DEFINITIONS[_pet_instance.base_name]
		if pet_def and pet_def.model:
			var model = pet_def.model.instantiate()
			pet_holder.add_child(model)
			_apply_effect(model, _pet_instance.type)
			_set_model_render_layer(model, RENDER_LAYER_PREVIEW)
	else:
		disabled = true
		if has_theme_stylebox_override("normal"):
			remove_theme_stylebox_override("normal")

# 🔹 Connecte le signal du bouton.
func _ready():
	pressed.connect(_on_pressed)

# 🔹 Gère le clic sur le slot pour demander un déséquipement.
func _on_pressed():
	if _pet_instance is Dictionary:
		unequip_requested.emit(_pet_instance.unique_id)

# --- Fonctions utilitaires (copiées de PetSlot.gd) ---
func _apply_effect(pet_node: Node3D, type_info: Dictionary):
	var mesh_instance = _find_mesh_recursively(pet_node)
	if not mesh_instance: return
	mesh_instance.material_overlay = null
	if type_info.effect_type == "shader" and type_info.value is String:
		var shader = load(type_info.value) as Shader
		if shader:
			var shader_material = ShaderMaterial.new()
			shader_material.shader = shader
			mesh_instance.material_overlay = shader_material

func _set_model_render_layer(node: Node, layer_number: int):
	var layer_mask = 1 << (layer_number - 1)
	if node is MeshInstance3D: node.layers = layer_mask
	for child in node.get_children(): _set_model_render_layer(child, layer_number)

func _find_mesh_recursively(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D: return node
	for child in node.get_children():
		var mesh = _find_mesh_recursively(child)
		if mesh: return mesh
	return null