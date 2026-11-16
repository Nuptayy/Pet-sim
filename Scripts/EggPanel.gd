# EggPanel.gd
extends PanelContainer

# --- Signaux ---
signal hatch_requested(egg_name, count)
signal select_requested(egg_name)
signal auto_delete_requested(egg_name)
signal offline_target_requested(egg_name)

# --- Constantes ---
const PetVisuals = preload("res://Scripts/PetVisuals.gd")

# --- Références aux Nœuds ---
@onready var preview_viewport_container: SubViewportContainer = %EggPreview

# --- État ---
var egg_name: String
var _egg_definition: Dictionary = {}


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Attend que la scène de preview soit prête, puis charge le modèle 3D.
func _ready():
	await get_tree().process_frame
	if preview_viewport_container.get_child_count() > 0:
		load_preview_model()
	else:
		printerr("ERREUR dans EggPanel: Le SubViewport est vide ou sa scène enfant n'est pas prête.")


# --- Méthodes Publiques ---

# 🔹 Configure le panneau avec les données d'un œuf et connecte les signaux.
func setup(egg_definition: Dictionary, number_of_egg_max: int):
	egg_name = egg_definition.name
	_egg_definition = egg_definition
	%Hatch1Button.text = "(E) Hatch 1 (%d Coins)" % egg_definition.cost
	%HatchMaxButton.text = "(R) Hatch %d" % number_of_egg_max
	%AutoHatchButton.text = "(T) Auto Hatch"
	%SelectButton.text = "Select"
	%Hatch1Button.pressed.connect(func(): hatch_requested.emit(egg_name, 1))
	%HatchMaxButton.pressed.connect(func(): hatch_requested.emit(egg_name, number_of_egg_max))
	%AutoHatchButton.pressed.connect(func(): hatch_requested.emit(egg_name, -1))
	%AutoDeleteButton.pressed.connect(func(): auto_delete_requested.emit(egg_name))
	%SelectButton.pressed.connect(func(): select_requested.emit(egg_name))
	%OfflineTargetButton.pressed.connect(func(): offline_target_requested.emit(egg_name))
	%OfflineTargetButton.visible = DataManager.get_upgrade_level("offline_rewards") > 0

# 🔹 Met à jour l'apparence du bouton "Select" pour indiquer s'il est actif.
func set_selected(is_selected: bool):
	%SelectButton.text = "Selected" if is_selected else "Select"
	%SelectButton.disabled = is_selected

# 🔹 Met à jour l'état visuel du bouton de cible hors ligne.
func set_as_offline_target(is_target: bool):
	%OfflineTargetButton.button_pressed = is_target


# --- Méthodes Internes ---

# 🔹 Charge le modèle 3D de l'œuf dans la fenêtre de prévisualisation.
func load_preview_model():
	if _egg_definition.is_empty():
		return
	var preview_scene = preview_viewport_container.get_child(0).get_child(0)
	var object_holder: Node3D = preview_scene.get_node_or_null("ObjectHolder")
	if not is_instance_valid(object_holder):
		printerr("ERREUR dans EggPanel: 'ObjectHolder' non trouvé dans la scène de preview.")
		return
	PetVisuals.clear_children(object_holder)
	var egg_model = _egg_definition.model.instantiate()
	object_holder.add_child(egg_model)
	PetVisuals.set_render_layer(egg_model, PetVisuals.RENDER_LAYER_EGG_PREVIEW)
