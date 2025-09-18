# PauseMenu.gd
extends CanvasLayer

# 🔹 Signaux pour communiquer avec le script principal.
signal continue_game
signal return_to_main_menu

@onready var options_menu = %OptionsMenu
@onready var stats_page = %StatsPage
@onready var main_buttons = %MainButtons

# 🔹 Initialisation du menu de pause.
func _ready():
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	
	hide()
	options_menu.hide()
	stats_page.hide()
	
	%ContinueButton.pressed.connect(on_continue_pressed)
	%StatsButton.pressed.connect(func(): show_submenu(stats_page))
	%OptionsButton.pressed.connect(func(): show_submenu(options_menu))
	%SaveAndExitButton.pressed.connect(on_return_to_menu_pressed)
	
	options_menu.back_pressed.connect(show_main_buttons)
	stats_page.back_pressed.connect(show_main_buttons)

# 🔹 Appelé quand on appuie sur le bouton "Continue".
func on_continue_pressed():
	hide()
	continue_game.emit()

# 🔹 Appelé quand on appuie sur le bouton "Return to Menu".
func on_return_to_menu_pressed():
	return_to_main_menu.emit()

func show_submenu(submenu_node: CanvasItem):
	main_buttons.hide()
	submenu_node.show()

func show_main_buttons():
	options_menu.hide()
	stats_page.hide()
	main_buttons.show()

# 🔹 Gère la pause et l'affichage.
func set_paused(is_paused: bool):
	if is_paused:
		show_main_buttons()
		show()
	else:
		hide()
