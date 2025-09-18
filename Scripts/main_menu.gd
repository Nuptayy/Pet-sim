# MainMenu.gd
extends Control

@onready var options_menu = %OptionsMenu
@onready var main_buttons = %MainButtons

func _ready():
	DataManager.progression_is_active = false
	options_menu.hide()
	%StartButton.pressed.connect(on_playgame_pressed)
	%OptionsButton.pressed.connect(on_options_pressed)
	%ExitButton.pressed.connect(on_exit_pressed)
	options_menu.back_pressed.connect(on_options_back_pressed)

func on_playgame_pressed():
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func on_options_pressed():
	main_buttons.hide()
	options_menu.show()

func on_exit_pressed():
	get_tree().quit()

func on_options_back_pressed():
	options_menu.hide()
	main_buttons.show()
