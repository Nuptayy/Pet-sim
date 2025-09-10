extends Control



func _on_playgame_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main_Game.tscn")

func _on_options_pressed() -> void:
	pass # Replace with function body.

func _on_exit_pressed() -> void:
	get_tree().quit()
