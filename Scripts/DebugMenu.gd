# DebugMenu.gd
extends PanelContainer

# 🔹 Initialise le menu de débogage et connecte tous ses boutons.
func _ready():
	# Permet au menu de fonctionner même si le jeu est en pause.
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Remplissage du dropdown des pets
	for pet_name in DataManager.PET_DEFINITIONS:
		%PetSelectDropdown.add_item(pet_name)
	
	# Connexions des boutons
	%GiveCoinsButton.pressed.connect(_on_give_coins_pressed)
	%GiveGemsButton.pressed.connect(_on_give_gems_pressed)
	%SetLuckButton.pressed.connect(_on_set_luck_pressed)
	%GivePetButton.pressed.connect(_on_give_pet_pressed)
	%CloseButton.pressed.connect(toggle_menu.bind(false))

# 🔹 Ajoute le montant de pièces spécifié au joueur.
func _on_give_coins_pressed():
	var amount = %CoinsInput.text.to_float()
	if amount > 0:
		DataManager.debug_add_coins(amount)
		%CoinsInput.clear()

# 🔹 Ajoute le montant de gemmes spécifié au joueur.
func _on_give_gems_pressed():
	var amount = %GemsInput.text.to_int()
	if amount > 0:
		DataManager.debug_add_gems(amount)
		%GemsInput.clear()

# 🔹 Définit le multiplicateur de chance permanent du joueur.
func _on_set_luck_pressed():
	var amount = %LuckInput.text.to_float()
	if amount > 0:
		DataManager.debug_set_luck(amount)
		%LuckInput.clear()

# 🔹 Ajoute un pet "Classic" de l'espèce sélectionnée à l'inventaire.
func _on_give_pet_pressed():
	if %PetSelectDropdown.selected == -1: return # Rien n'est sélectionné
	
	var pet_name = %PetSelectDropdown.get_item_text(%PetSelectDropdown.selected)
	var classic_type = DataManager.PET_TYPES[0] # On donne un "Classic" par défaut
	
	DataManager.add_pet_to_inventory(pet_name, classic_type)
	print("DEBUG: Gave player 1x Classic %s" % pet_name)

# 🔹 Affiche/cache le menu et gère la pause du jeu.
func toggle_menu(is_open: bool):
	self.visible = is_open
	get_tree().paused = is_open
