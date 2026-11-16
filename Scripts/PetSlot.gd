# PetSlot.gd
extends Button

# --- Constantes ---
const PetIconCache = preload("res://Scripts/PetIconCache.gd")
const EQUIPPED_STYLE = preload("res://style/equipped_style.tres")

# --- Références aux Nœuds ---
@onready var icon_rect: TextureRect = %PetIcon


# --- Méthodes Publiques ---

# 🔹 Configure le slot avec la vignette et l'infobulle d'un pet.
func setup(pet_instance: Dictionary):
	tooltip_text = "%s (%s)" % [pet_instance.base_name, pet_instance.type.name]
	icon_rect.texture = PetIconCache.get_icon(pet_instance.base_name, pet_instance.type)
	_update_equipped_style(pet_instance.get("unique_id", -1))

# 🔹 Configure le slot pour un groupe de pets identiques, avec son compteur.
func setup_grouped(pet_group: Dictionary):
	setup(pet_group.data)
	%CountLabel.text = "x%d" % pet_group.count
	%CountLabel.visible = pet_group.count > 1


# --- Badge "Nouveau" ---

# 🔹 Affiche un petit cercle rouge "!" en haut à droite du slot.
func show_new_badge():
	if has_node("NewBadge"):
		return
	var badge = Panel.new()
	badge.name = "NewBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -26
	badge.offset_top = 3
	badge.offset_right = -3
	badge.offset_bottom = 26
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.12, 0.12, 1.0)
	style.set_corner_radius_all(12)
	badge.add_theme_stylebox_override("panel", style)
	var label = Label.new()
	label.text = "!"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 13)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	add_child(badge)

# 🔹 Retire le badge "Nouveau".
func hide_new_badge():
	if has_node("NewBadge"):
		get_node("NewBadge").queue_free()


# --- Marque de Suppression ---

# 🔹 Affiche un voile rouge avec la quantité à supprimer, ou le retire si la quantité est nulle.
func show_delete_mark(quantity: int):
	var mark: Panel = get_node_or_null("DeleteMark")
	if quantity <= 0:
		if mark != null:
			mark.visible = false
		return
	if mark == null:
		mark = _create_delete_mark()
	mark.visible = true
	mark.get_node("QuantityLabel").text = "-%d" % quantity

# 🔹 Crée le voile rouge de suppression et son étiquette de quantité.
func _create_delete_mark() -> Panel:
	var mark = Panel.new()
	mark.name = "DeleteMark"
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.85, 0.1, 0.1, 0.45)
	style.border_color = Color(1.0, 0.2, 0.2, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	mark.add_theme_stylebox_override("panel", style)
	var label = Label.new()
	label.name = "QuantityLabel"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_font_size_override("font_size", 28)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.add_child(label)
	add_child(mark)
	return mark


# --- Méthodes Internes ---

# 🔹 Applique le style "équipé" si le pet fait partie de l'équipe.
func _update_equipped_style(pet_id: int):
	if pet_id in DataManager.equipped_pets:
		add_theme_stylebox_override("normal", EQUIPPED_STYLE)
	elif has_theme_stylebox_override("normal"):
		remove_theme_stylebox_override("normal")
