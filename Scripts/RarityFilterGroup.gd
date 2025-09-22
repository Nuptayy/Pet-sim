# RarityFilterGroup.gd
extends VBoxContainer

signal filter_changed

var rarity_name: String
var type_checkboxes: Dictionary = {}
var _is_updating = false

func _ready():
	%RarityCheckbox.toggled.connect(on_rarity_checkbox_toggled)

# 🔹 Configure le groupe avec les données et les filtres actuels.
func setup(r_name: String, all_types: Array, current_type_filters: Array):
	self.rarity_name = r_name
	%RarityCheckbox.text = r_name
	
	var type_container = %TypeContainer
	for type_info in all_types:
		var type_name = type_info["name"]
		var checkbox = CheckBox.new()
		checkbox.text = type_name
		checkbox.button_pressed = type_name in current_type_filters
		checkbox.toggled.connect(on_any_child_checkbox_changed)
		type_container.add_child(checkbox)
		type_checkboxes[type_name] = checkbox
	
	update_main_checkbox_state()

# 🔹 Appelé quand la case principale (rareté) est cochée/décochée.
func on_rarity_checkbox_toggled(is_on: bool):
	if _is_updating: return
	_is_updating = true
	for checkbox in type_checkboxes.values():
		checkbox.button_pressed = is_on
	_is_updating = false
	filter_changed.emit()

# 🔹 Appelé quand une case de type (enfant) est cochée/décochée.
func on_any_child_checkbox_changed(_is_on: bool):
	if _is_updating: return
	update_main_checkbox_state()
	filter_changed.emit()

# 🔹 Met à jour l'état visuel de la case "maître".
func update_main_checkbox_state():
	_is_updating = true
	
	var all_checked = true
	for checkbox in type_checkboxes.values():
		if not checkbox.button_pressed:
			all_checked = false
			break
	
	%RarityCheckbox.button_pressed = all_checked
	_is_updating = false

# 🔹 Fonction publique pour que le menu parent puisse récupérer les choix.
func get_selected_types() -> Array[String]:
	var selected: Array[String] = []
	for type_name in type_checkboxes:
		if type_checkboxes[type_name].button_pressed:
			selected.append(type_name)
	return selected
