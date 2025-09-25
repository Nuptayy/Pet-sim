# PauseMenu.gd
extends CanvasLayer

# --- Signaux ---
signal continue_game
signal return_to_main_menu

# --- Références aux Nœuds ---
@onready var options_menu: PanelContainer = %OptionsMenu
@onready var stats_page: PanelContainer = %StatsPage
@onready var main_buttons: VBoxContainer = %MainButtons


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Initialise le menu, connecte les signaux et s'assure qu'il est invisible au départ.
func _ready():
	# Permet au menu de fonctionner même si le jeu est en pause.
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Cache tous les éléments au démarrage.
	hide()
	options_menu.hide()
	stats_page.hide()
	
	# Connexions des boutons du menu principal.
	%ContinueButton.pressed.connect(_on_continue_pressed)
	%StatsButton.pressed.connect(func(): _show_submenu(stats_page))
	%OptionsButton.pressed.connect(func(): _show_submenu(options_menu))
	%SaveAndExitButton.pressed.connect(_on_return_to_menu_pressed)
	
	# Connexions des boutons "Retour" des sous-menus.
	options_menu.back_pressed.connect(_show_main_buttons)
	stats_page.back_pressed.connect(_show_main_buttons)


# --- Méthodes Publiques ---

# 🔹 Gère l'affichage ou le masquage du menu de pause.
func set_paused(is_paused: bool):
	if is_paused:
		_show_main_buttons() # Affiche les boutons principaux du menu pause.
		show()
	else:
		hide()


# --- Fonctions de Rappel (Signal Callbacks) ---

# 🔹 Gère l'action du bouton "Continue".
func _on_continue_pressed():
	hide()
	continue_game.emit()

# 🔹 Gère l'action du bouton "Save and Exit".
func _on_return_to_menu_pressed():
	return_to_main_menu.emit()


# --- Méthodes de Navigation Interne ---

# 🔹 Affiche un sous-menu spécifique (Options ou Stats).
func _show_submenu(submenu_node: CanvasItem):
	main_buttons.hide()
	submenu_node.show()

# 🔹 Affiche les boutons principaux et cache tous les sous-menus.
func _show_main_buttons():
	options_menu.hide()
	stats_page.hide()
	main_buttons.show()
