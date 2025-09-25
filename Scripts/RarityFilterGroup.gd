# RarityFilterGroup.gd
extends VBoxContainer

# --- Signaux ---
signal filter_changed

# --- État ---
var rarity_name: String
var type_checkboxes: Dictionary = {}
var _is_updating: bool = false # Verrou pour éviter les signaux en cascade


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Connecte le signal de la case à cocher principale.
func _ready():
	%RarityCheckbox.toggled.connect(_on_rarity_checkbox_toggled)


# --- Méthodes Publiques ---

# 🔹 Configure le groupe avec un nom de rareté et les filtres de type actuels.
func setup(r_name: String, all_types: Array, current_type_filters: Array):
	self.rarity_name = r_name
	%RarityCheckbox.text = r_name
	
	# Crée dynamiquement une case à cocher pour chaque type de pet.
	var type_container = %TypeContainer
	for type_info in all_types:
		var type_name = type_info.name
		var checkbox = CheckBox.new()
		checkbox.text = type_name
		checkbox.button_pressed = type_name in current_type_filters
		checkbox.toggled.connect(_on_any_child_checkbox_changed)
		type_container.add_child(checkbox)
		type_checkboxes[type_name] = checkbox
	
	_update_main_checkbox_state()

# 🔹 Retourne la liste des noms de types actuellement sélectionnés dans ce groupe.
func get_selected_types() -> Array[String]:
	var selected: Array[String] = []
	for type_name in type_checkboxes:
		if type_checkboxes[type_name].button_pressed:
			selected.append(type_name)
	return selected


# --- Fonctions de Rappel (Signal Callbacks) ---

# 🔹 Gère le clic sur la case à cocher principale (la rareté), cochant/décochant tous les types.
func _on_rarity_checkbox_toggled(is_on: bool):
	if _is_updating: return
	
	_is_updating = true
	for checkbox in type_checkboxes.values():
		checkbox.button_pressed = is_on
	_is_updating = false
	
	filter_changed.emit()

# 🔹 Gère le clic sur n'importe quelle case de type, mettant à jour l'état de la case principale.
func _on_any_child_checkbox_changed(_is_on: bool):
	if _is_updating: return
	
	_update_main_checkbox_state()
	filter_changed.emit()


# --- Méthodes Internes ---

# 🔹 Met à jour l'état de la case à cocher principale (cochée, décochée, ou indéterminée).
func _update_main_checkbox_state():
	if _is_updating: return
	_is_updating = true
	
	var all_checked = true
	var none_checked = true
	
	for checkbox in type_checkboxes.values():
		if checkbox.button_pressed:
			none_checked = false
		else:
			all_checked = false
	
	# Si toutes les cases sont cochées, la principale est cochée.
	# Si aucune n'est cochée, la principale est décochée.
	# Sinon, elle est dans un état intermédiaire.
	if all_checked:
		%RarityCheckbox.button_pressed = true
	elif none_checked:
		%RarityCheckbox.button_pressed = false
	else:
		# L'état indéterminé n'est pas supporté par CheckBox, donc on la décoche
		# pour montrer que "tout" n'est pas sélectionné.
		%RarityCheckbox.button_pressed = false

	_is_updating = false
