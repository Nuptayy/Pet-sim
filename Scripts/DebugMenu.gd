# DebugMenu.gd
extends PanelContainer

# --- État ---
var _type_dropdown: OptionButton
var _pet_count_spin: SpinBox
var _offline_hours_spin: SpinBox
var _index_percent_spin: SpinBox


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Construit les contrôles du menu et connecte tous les boutons de triche.
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_pet_row()
	var button_list = get_child(0)
	_add_button(button_list, "Finish Index (tout découvrir)", _run.bind("finish_index", []))
	_add_button(button_list, "Donner tous les pets (Classic)", _run.bind("give_all_pets", [false]))
	_add_button(button_list, "Donner tous les pets (tous types)", _run.bind("give_all_pets", [true]))
	_add_button(button_list, "Reset Stats", _run.bind("reset_stats", []))
	_add_button(button_list, "Reset Index", _run.bind("reset_index", []))
	_add_button(button_list, "Reset Inventaire", _run.bind("reset_inventory", []))
	_add_button(button_list, "Reset Types découverts", _run.bind("reset_discovered_types", []))
	_add_button(button_list, "Reset ALL", _run.bind("reset_all", []))
	_add_button(button_list, "Sauvegarde forcée", _run.bind("force_save", []))
	_offline_hours_spin = _add_spin_row(button_list, "Heures:", 1, 168, 8, "Force Offline Reward", _on_force_offline_reward_pressed)
	_index_percent_spin = _add_spin_row(button_list, "Index %:", 0, 100, 50, "Forcer Index à X%", _on_force_index_pressed)
	_add_button(button_list, "Stress Test (1000 pets -> inventaire)", _on_stress_test_pressed)
	button_list.move_child(%CloseButton, button_list.get_child_count() - 1)
	%GiveCoinsButton.pressed.connect(_on_give_coins_pressed)
	%GiveGemsButton.pressed.connect(_on_give_gems_pressed)
	%SetLuckButton.pressed.connect(_on_set_luck_pressed)
	%GivePetButton.pressed.connect(_on_give_pet_pressed)
	%CloseButton.pressed.connect(toggle_menu.bind(false))


# --- Méthodes Publiques ---

# 🔹 Ouvre ou ferme le menu en mettant le jeu en pause.
func toggle_menu(is_open: bool):
	visible = is_open
	get_tree().paused = is_open


# --- Construction de l'Interface ---

# 🔹 Complète la ligne de don de pet avec le choix du type et de la quantité.
func _build_pet_row():
	for pet_name in GameConfig.PET_DEFINITIONS:
		%PetSelectDropdown.add_item(pet_name)
	var pet_row = %PetSelectDropdown.get_parent()
	_type_dropdown = OptionButton.new()
	for type_info in GameConfig.PET_TYPES:
		_type_dropdown.add_item(type_info.name)
	pet_row.add_child(_type_dropdown)
	pet_row.move_child(_type_dropdown, %PetSelectDropdown.get_index() + 1)
	_pet_count_spin = _create_spin(1, 9999, 1)
	pet_row.add_child(_pet_count_spin)
	pet_row.move_child(_pet_count_spin, _type_dropdown.get_index() + 1)

# 🔹 Ajoute un bouton pleine largeur relié à une action.
func _add_button(parent: Node, label: String, callback: Callable):
	var button = Button.new()
	button.text = label
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)

# 🔹 Ajoute une ligne "label + valeur numérique + bouton" et retourne le champ numérique.
func _add_spin_row(parent: Node, label_text: String, min_value: float, max_value: float, value: float, button_text: String, callback: Callable) -> SpinBox:
	var row = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text
	row.add_child(label)
	var spin = _create_spin(min_value, max_value, value)
	row.add_child(spin)
	_add_button(row, button_text, callback)
	parent.add_child(row)
	return spin

# 🔹 Crée un champ numérique borné.
func _create_spin(min_value: float, max_value: float, value: float) -> SpinBox:
	var spin = SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.value = value
	spin.custom_minimum_size = Vector2(80, 0)
	return spin


# --- Fonctions de Rappel (Signal Callbacks) ---

# 🔹 Exécute une commande de triche du backend et retourne son résultat.
func _run(command: String, arguments: Array) -> Dictionary:
	return await Backend.debug(command, arguments)

# 🔹 Donne le nombre de coins saisi, ou en retire s'il est négatif.
func _on_give_coins_pressed():
	var amount = %CoinsInput.text.to_float()
	if amount != 0:
		_run("add_coins", [amount])
		%CoinsInput.clear()

# 🔹 Donne le nombre de gems saisi, ou en retire s'il est négatif.
func _on_give_gems_pressed():
	var amount = %GemsInput.text.to_int()
	if amount != 0:
		_run("add_gems", [amount])
		%GemsInput.clear()

# 🔹 Force la chance permanente à la valeur saisie.
func _on_set_luck_pressed():
	var amount = %LuckInput.text.to_float()
	if amount > 0:
		_run("set_luck", [amount])
		%LuckInput.clear()

# 🔹 Donne le pet choisi, dans le type et la quantité choisis.
func _on_give_pet_pressed():
	if %PetSelectDropdown.selected == -1:
		return
	var pet_name = %PetSelectDropdown.get_item_text(%PetSelectDropdown.selected)
	var type_name = _type_dropdown.get_item_text(max(0, _type_dropdown.selected))
	_run("give_pets", [pet_name, type_name, int(_pet_count_spin.value)])

# 🔹 Simule et applique le nombre d'heures hors ligne choisi.
func _on_force_offline_reward_pressed():
	var result = await _run("force_offline", [int(_offline_hours_spin.value)])
	if result.ok:
		print("DEBUG: hors ligne — Coins: +%d, Gems: +%d, Oeufs: %d" % [result.rewards.net_coin_gain, result.rewards.earned_gems, result.rewards.eggs_hatched])

# 🔹 Découvre assez de pets pour atteindre le pourcentage d'index choisi.
func _on_force_index_pressed():
	await _run("force_index", [_index_percent_spin.value])
	print("DEBUG: index à %.2f%%" % DataManager.get_index_completion())

# 🔹 Ajoute 1000 pets et affiche le temps pris.
func _on_stress_test_pressed():
	var result = await _run("stress_test", [])
	if result.ok:
		print("DEBUG: stress test — 1000 pets en %dms | Inventaire: %d pets" % [result.elapsed_ms, DataManager.player_inventory.size()])
