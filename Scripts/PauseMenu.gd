# PauseMenu.gd
extends CanvasLayer

# 🔹 Signaux pour communiquer avec le script principal.
signal continue_game
signal return_to_main_menu

# 🔹 Initialisation du menu de pause.
func _ready():
	hide()
	%ContinueButton.pressed.connect(on_continue_pressed)
	%OptionsButton.disabled = true
	%SaveAndExitButton.pressed.connect(on_return_to_menu_pressed)

# 🔹 Appelé quand on appuie sur le bouton "Continue".
func on_continue_pressed():
	hide()
	continue_game.emit()

# 🔹 Appelé quand on appuie sur le bouton "Return to Menu".
func on_return_to_menu_pressed():
	return_to_main_menu.emit()

# 🔹 Gère la pause et l'affichage.
func set_paused(is_paused: bool):
	if is_paused:
		show()
	else:
		hide()
