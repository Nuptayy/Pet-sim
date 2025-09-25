# EggPanel.gd
extends PanelContainer

# --- Signaux ---
signal hatch_requested(egg_name, count)
signal select_requested(egg_name)
signal auto_delete_requested(egg_name)

# --- Références aux Nœuds ---
@onready var preview_viewport_container: SubViewportContainer = %EggPreview

# --- État ---
var egg_name: String


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Attend que la scène de preview soit prête, puis charge le modèle 3D.
func _ready():
	# On attend la fin de la frame pour garantir que la scène de preview est instanciée.
	await get_tree().process_frame
	
	if preview_viewport_container.get_child_count() > 0:
		load_preview_model()
	else:
		printerr("ERREUR dans EggPanel: Le SubViewport est vide ou sa scène enfant n'est pas prête.")


# --- Méthodes Publiques ---

# 🔹 Configure le panneau avec les données d'un œuf et connecte les signaux.
func setup(egg_definition: Dictionary, number_of_egg_max: int):
	self.egg_name = egg_definition.name
	
	# Stocke les données de l'œuf pour un accès ultérieur.
	set_meta("egg_definition", egg_definition)

	# Configure l'affichage des boutons.
	%Hatch1Button.text = "Hatch 1 (%d Coins)" % egg_definition.cost
	%HatchMaxButton.text = "Hatch %d" % number_of_egg_max
	%AutoHatchButton.text = "Auto Hatch"
	%SelectButton.text = "Select"
	
	# Connecte les signaux des boutons.
	%Hatch1Button.pressed.connect(func(): hatch_requested.emit(egg_name, 1))
	%HatchMaxButton.pressed.connect(func(): hatch_requested.emit(egg_name, number_of_egg_max))
	%AutoHatchButton.pressed.connect(func(): hatch_requested.emit(egg_name, -1)) # -1 pour Auto-Hatch
	%AutoDeleteButton.pressed.connect(func(): auto_delete_requested.emit(egg_name))
	%SelectButton.pressed.connect(func(): select_requested.emit(egg_name))
	
# 🔹 Met à jour l'apparence du bouton "Select" pour indiquer s'il est actif.
func set_selected(is_selected: bool):
	if is_selected:
		%SelectButton.text = "Selected"
		%SelectButton.disabled = true
	else:
		%SelectButton.text = "Select"
		%SelectButton.disabled = false


# --- Méthodes Internes ---

# 🔹 Charge le modèle 3D de l'œuf dans la fenêtre de prévisualisation.
func load_preview_model():
	if not has_meta("egg_definition"): return
	
	var egg_definition = get_meta("egg_definition")
	
	# Accède au conteneur du modèle 3D dans la scène de preview.
	var preview_scene = preview_viewport_container.get_child(0).get_child(0)
	var object_holder: Node3D = preview_scene.get_node("ObjectHolder")

	if is_instance_valid(object_holder):
		# Nettoie l'ancien modèle et instancie le nouveau.
		for child in object_holder.get_children():
			child.queue_free()
 
		var egg_model = egg_definition.model.instantiate()
		object_holder.add_child(egg_model)
 
		# Assigne le modèle à la bonne couche de rendu pour la preview.
		var visual_node = _find_mesh_recursively(egg_model)
		if visual_node:
			visual_node.layers = 2 # Couche 2: Previews 3D des œufs
	else:
		printerr("ERREUR dans EggPanel: 'ObjectHolder' non trouvé dans la scène de preview.")


# --- Fonctions Utilitaires ---

# 🔹 Trouve récursivement le premier nœud MeshInstance3D dans une hiérarchie.
func _find_mesh_recursively(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var mesh = _find_mesh_recursively(child)
		if mesh:
			return mesh
	return null
