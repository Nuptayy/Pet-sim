# Boot.gd
extends Node

func _ready():
	SaveManager.load_all()
	get_tree().scene_changed.connect(on_scene_changed)
	get_tree().change_scene_to_file.call_deferred("res://Scenes/Main_menu.tscn")

# 🔹 Cette fonction est appelée automatiquement après chaque changement de scène.
func on_scene_changed():
	Engine.max_fps = SaveManager.load_setting("display", "fps_limit", 0)
	print("Vérification et application de la limite de FPS : ", Engine.max_fps)
