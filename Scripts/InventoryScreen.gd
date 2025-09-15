# InventoryScreen.gd
extends PanelContainer

signal close_requested

const PET_SLOT_SCENE = preload("res://Scenes/PetSlot.tscn")
var current_selected_pet_id = -1

# 🔹 Références aux nœuds de l'interface (utilisez la notation % pour plus de sécurité).
@onready var details_panel: PanelContainer = %DetailsPanel
@onready var pet_grid: GridContainer = %PetGrid
@onready var close_button: Button = %CloseButton
@onready var delete_button: Button = %DeleteButton
@onready var pet_count_label: Label = %PetCountLabel
@onready var pet_holder: Node3D = %PetHolder
@onready var pet_name_label: Label = %PetNameLabel
@onready var rarity_label: Label = %RarityLabel
@onready var chance_label: Label = %ChanceLabel
@onready var power_label: Label = %PowerLabel
@onready var luck_boost_label: Label = %LuckBoostLabel
@onready var speed_boost_label: Label = %SpeedBoostLabel

func _ready():
	%DetailsPanel.visible = false
	%CloseButton.pressed.connect(func(): close_requested.emit())
	%DeleteButton.pressed.connect(_on_delete_pressed)
	DataManager.inventory_updated.connect(redraw_inventory)
	DataManager.total_pet_count_changed.connect(_update_total_count)
	redraw_inventory()
	_update_total_count(DataManager.player_inventory.size())

func redraw_inventory():
	for child in %PetGrid.get_children():
		child.queue_free()
	for pet_instance in DataManager.player_inventory:
		var slot = PET_SLOT_SCENE.instantiate()
		%PetGrid.add_child(slot)
		slot.setup(pet_instance)
		slot.pressed.connect(display_pet_details.bind(pet_instance["unique_id"]))

func display_pet_details(pet_id: int):
	current_selected_pet_id = pet_id
	%DetailsPanel.visible = true
	var pet_data = DataManager.get_pet_by_id(pet_id)
	if pet_data.is_empty(): 
		%DetailsPanel.visible = false
		return

	var base_pet_def = DataManager.pet_definitions[pet_data["base_name"]]
	var rarity_def = DataManager.rarities[base_pet_def["rarity"]]
	
	%PetNameLabel.text = "%s (%s)" % [pet_data["base_name"], pet_data["type"]["name"]]
	%RarityLabel.text = base_pet_def["rarity"]
	%RarityLabel.add_theme_color_override("font_color", rarity_def["color"])
	%ChanceLabel.text = "(1 in %s)" % format_chance(base_pet_def["chance"])
	
	%PowerLabel.text = "Power: %s" % pet_data["stats"]["Power"]
	%LuckBoostLabel.text = "Luck Boost: x%s" % pet_data["stats"]["LuckBoost"]
	%SpeedBoostLabel.text = "Speed Boost: x%s" % pet_data["stats"]["SpeedBoost"]
	
	var pet_holder = %PetHolder
	for child in pet_holder.get_children():
		child.queue_free()
	var pet_model = base_pet_def["model"].instantiate()
	pet_holder.add_child(pet_model)
	
	apply_preview_effect(pet_model, pet_data["type"])

func _on_delete_pressed():
	if current_selected_pet_id != -1:
		DataManager.remove_pet_by_id(current_selected_pet_id)
		%DetailsPanel.visible = false
		current_selected_pet_id = -1

func _update_total_count(new_count: int):
	%PetCountLabel.text = "%d / %d" % [new_count, 250]

func _process(delta):
	if %DetailsPanel.visible and %PetHolder.get_child_count() > 0:
		%PetHolder.get_child(0).rotate_y(delta * 0.5)

func format_chance(chance_percent: float) -> String:
	if chance_percent <= 0: return "∞"
	if chance_percent >= 1.0: return str(round(100.0 / chance_percent))
	var denominator = 1.0 / (chance_percent / 100.0)
	if denominator > 1000000: return "%.1fM" % (denominator / 1000000.0)
	if denominator > 1000: return "%.1fK" % (denominator / 1000.0)
	return str(round(denominator))

func apply_preview_effect(pet_node: Node3D, type_info: Dictionary):
	var mesh_instance = find_mesh_recursively(pet_node)
	if not mesh_instance:
		printerr("Preview: Impossible de trouver un MeshInstance3D pour le pet.")
		return
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
			else:
				printerr("Preview: Impossible de charger le shader: ", effect_value)

func find_mesh_recursively(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D: return node
	for child in node.get_children():
		var mesh = find_mesh_recursively(child)
		if mesh: return mesh
	return null
