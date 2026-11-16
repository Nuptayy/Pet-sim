# main_menu.gd
extends Control

# --- Références aux Nœuds ---
@onready var options_menu: PanelContainer = %OptionsMenu
@onready var main_buttons: VBoxContainer = %MainButtons


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Initialise le menu principal, connecte les boutons et s'assure que la progression est inactive.
func _ready():
	Backend.stop_session()
	options_menu.hide()
	%StartButton.pressed.connect(_on_play_game_pressed)
	options_menu.back_pressed.connect(_on_options_back_pressed)


# --- Fonctions de Rappel (Signal Callbacks) ---

# 🔹 Lance la scène de jeu principale.
func _on_play_game_pressed():
	get_tree().change_scene_to_file("res://Scenes/LoadingScreen.tscn")

# 🔹 Affiche le sous-menu des options et cache les boutons principaux.
func _on_options_pressed():
	main_buttons.hide()
	options_menu.show()

# 🔹 Ferme l'application.
func _on_exit_pressed():
	get_tree().quit()

# 🔹 Gère le retour depuis le sous-menu des options.
func _on_options_back_pressed():
	options_menu.hide()
	main_buttons.show()
