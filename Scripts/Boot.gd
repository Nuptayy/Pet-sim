# Boot.gd
extends Node

# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Initialise le jeu en chargeant les données et en lançant le menu principal.
func _ready():
	SaveManager.load_all()
	get_tree().change_scene_to_file.call_deferred("res://Scenes/Main_menu.tscn")
