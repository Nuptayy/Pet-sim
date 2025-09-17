extends Control

func _ready():
	%StartButton.pressed.connect(on_playgame_pressed)
	%OptionsButton.disabled = true
	%ExitButton.pressed.connect(on_exit_pressed)

func on_playgame_pressed():
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func _on_options_pressed():
	pass # Replace with function body.

func on_exit_pressed():
	get_tree().quit()
