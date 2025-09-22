# IndexScreen.gd
extends PanelContainer

signal close_requested

const INDEX_SLOT_SCENE = preload("res://Scenes/IndexSlot.tscn")
const PETS_PER_ROW = 6

@onready var index_container = %IndexContainer
@onready var close_button = %CloseButton

func _ready():
	close_button.pressed.connect(func(): close_requested.emit())
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed():
	if visible:
		build_index()

# 🔹 Construit ou reconstruit l'index complet, groupé par œuf.
func build_index():
	for child in index_container.get_children():
		child.queue_free()
	
	for egg_def in DataManager.egg_definitions:
		var egg_title = Label.new()
		egg_title.text = egg_def["name"]
		egg_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if index_container.get_child_count() > 0:
			var separator = Control.new()
			separator.custom_minimum_size.y = 40
			index_container.add_child(separator)
			
		index_container.add_child(egg_title)
		
		var pet_grid = GridContainer.new()
		pet_grid.columns = PETS_PER_ROW
		pet_grid.add_theme_constant_override("h_separation", 10)
		pet_grid.add_theme_constant_override("v_separation", 10)
		index_container.add_child(pet_grid)
		
		var pets_in_this_egg = egg_def["pets"]
		
		for pet_info_in_egg in pets_in_this_egg:
			var pet_name = pet_info_in_egg["name"]
			var is_discovered = DataManager.discovered_pets.has(pet_name)
			
			var slot = INDEX_SLOT_SCENE.instantiate()
			pet_grid.add_child(slot)
			slot.setup(pet_name, is_discovered)
