# Boot.gd
extends Node

func _ready():
	# Charge les options sauvegardées.
	SaveManager.load_options()

	# Une fois les options chargées, on passe au menu principal.
	get_tree().change_scene_to_file("res://Scenes/Main_menu.tscn")
