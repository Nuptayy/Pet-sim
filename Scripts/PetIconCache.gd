# PetIconCache.gd
extends RefCounted

# --- Constantes ---
const PetVisuals = preload("res://Scripts/PetVisuals.gd")
const PREVIEW_SCENE = preload("res://Scenes/PetPreview3D.tscn")
const ICON_SIZE = 128
const RENDER_FRAMES = 2

# --- État Partagé ---
static var _icons: Dictionary = {}


# --- Méthodes Publiques ---

# 🔹 Retourne la vignette d'un couple (pet, type), rendue une seule fois puis partagée par tous les slots.
static func get_icon(pet_base_name: String, type_info: Dictionary, is_silhouette: bool = false) -> Texture2D:
	if not GameConfig.PET_DEFINITIONS.has(pet_base_name):
		return null
	var key = "%s|%s|%s" % [pet_base_name, type_info.get("name", ""), is_silhouette]
	if not _icons.has(key):
		var icon = ImageTexture.new()
		_icons[key] = icon
		_render_icon(icon, pet_base_name, type_info, is_silhouette)
	return _icons[key]

# 🔹 Vide le cache pour forcer un nouveau rendu des vignettes.
static func clear():
	_icons.clear()


# --- Méthodes Internes ---

# 🔹 Rend le modèle dans un SubViewport temporaire et copie le résultat dans la texture.
static func _render_icon(icon: ImageTexture, pet_base_name: String, type_info: Dictionary, is_silhouette: bool):
	var tree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.gui_disable_input = true
	viewport.size = Vector2i(ICON_SIZE, ICON_SIZE)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var preview = PREVIEW_SCENE.instantiate()
	viewport.add_child(preview)
	var model = PetVisuals.create_pet_model(pet_base_name, type_info, PetVisuals.RENDER_LAYER_PET_PREVIEW)
	if is_silhouette:
		PetVisuals.apply_silhouette(model)
	preview.get_node("ObjectHolder").add_child(model)
	tree.root.add_child.call_deferred(viewport)
	await viewport.ready
	for i in RENDER_FRAMES:
		await RenderingServer.frame_post_draw
	var image = viewport.get_texture().get_image()
	if image != null and not image.is_empty():
		icon.set_image(image)
	viewport.queue_free()
