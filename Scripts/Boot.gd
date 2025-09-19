# Boot.gd
extends Node

func _ready():
	SaveManager.load_all()
	get_tree().change_scene_to_file("res://Scenes/Main_menu.tscn")

# 🔹 Cette fonction est appelée automatiquement après chaque changement de scène.
func on_scene_changed():
	Engine.max_fps = SaveManager.current_settings["fps_limit"]
	print("Limite de FPS ré-appliquée sur la nouvelle scène : ", Engine.max_fps)
