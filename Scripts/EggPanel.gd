# EggPanel.gd
extends PanelContainer

signal hatch_requested(egg_name, count)
signal select_requested(egg_name)

var egg_name: String

func setup(egg_definition: Dictionary, number_of_egg_max: int):
	self.egg_name = egg_definition["name"]
	%Hatch1Button.text = "Hatch 1"
	%HatchMaxButton.text = "Hatch %d" % number_of_egg_max
	%AutoHatchButton.text = "Auto Hatch"
	%SelectButton.text = "Select"
	
	%Hatch1Button.pressed.connect(func(): hatch_requested.emit(egg_name, 1))
	%HatchMaxButton.pressed.connect(func(): hatch_requested.emit(egg_name, number_of_egg_max))
	%AutoHatchButton.pressed.connect(func(): hatch_requested.emit(egg_name, -1))
	%SelectButton.pressed.connect(func(): select_requested.emit(egg_name))

func set_selected(is_selected: bool):
	if is_selected:
		%SelectButton.text = "Selected"
		%SelectButton.disabled = true
	else:
		%SelectButton.text = "Select"
		%SelectButton.disabled = false
