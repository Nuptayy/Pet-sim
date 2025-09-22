# EggPanel.gd
extends PanelContainer

signal hatch_requested(egg_name, count)
signal select_requested(egg_name)
signal auto_delete_requested(egg_name)

var egg_name: String
@onready var preview_viewport_container: SubViewportContainer = %EggPreview

# 🔹 La fonction _ready est appelée une fois que tous les enfants sont prêts.
func _ready():
	if preview_viewport_container.get_child(0).get_child_count() > 0:
		var preview_scene = preview_viewport_container.get_child(0).get_child(0)
		# On attend que la scène de preview soit complètement prête avant de charger le modèle.
		preview_scene.ready.connect(_on_preview_ready)
	else:
		printerr("ERREUR dans EggPanel: Le SubViewport est vide.")

# 🔹 Cette fonction est appelée une fois que la scène de preview est prête.
func _on_preview_ready():
	load_preview_model()
	
# 🔹 Configure les informations textuelles et les connexions des boutons.
func setup(egg_definition: Dictionary, number_of_egg_max: int):
	self.egg_name = egg_definition["name"]
	
	%Hatch1Button.text = "Hatch 1"
	%HatchMaxButton.text = "Hatch %d" % number_of_egg_max
	%AutoHatchButton.text = "Auto Hatch"
	%SelectButton.text = "Select"
	
	%Hatch1Button.pressed.connect(func(): hatch_requested.emit(egg_name, 1))
	%HatchMaxButton.pressed.connect(func(): hatch_requested.emit(egg_name, number_of_egg_max))
	%AutoHatchButton.pressed.connect(func(): hatch_requested.emit(egg_name, -1))
	%AutoDeleteButton.pressed.connect(func(): auto_delete_requested.emit(egg_name))
	%SelectButton.pressed.connect(func(): select_requested.emit(egg_name))
	
	# Important: on doit stocker les données de l'œuf pour les utiliser plus tard.
	set_meta("egg_definition", egg_definition)

# 🔹 Charge le bon modèle 3D dans la preview.
func load_preview_model():
	if not has_meta("egg_definition"): return
	var egg_definition = get_meta("egg_definition")
	
	var preview_scene = preview_viewport_container.get_child(0).get_child(0)
	var object_holder: Node3D = preview_scene.get_node("ObjectHolder")

	if is_instance_valid(object_holder):
		for child in object_holder.get_children():
			child.queue_free()
		
		var egg_model = egg_definition["model"].instantiate()
		object_holder.add_child(egg_model)
		
		var visual_node = find_mesh_recursively(egg_model)
		if visual_node:
			visual_node.layers = 2
	else:
		printerr("ERREUR dans EggPanel load_preview_model: object_holder n'est pas valide.")

# 🔹 Met à jour l'apparence du bouton "Select".
func set_selected(is_selected: bool):
	if is_selected:
		%SelectButton.text = "Selected"
		%SelectButton.disabled = true
	else:
		%SelectButton.text = "Select"
		%SelectButton.disabled = false

# 🔹 Fonction utilitaire pour trouver le mesh visible.
func find_mesh_recursively(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D: return node
	for child in node.get_children():
		var mesh = find_mesh_recursively(child)
		if mesh: return mesh
	return null
