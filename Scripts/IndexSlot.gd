# IndexSlot.gd
extends PanelContainer

# --- Constantes ---
const PetIconCache = preload("res://Scripts/PetIconCache.gd")

# --- Références aux Nœuds ---
@onready var pet_name_label: Label = %PetNameLabel
@onready var icon_rect: TextureRect = %PetPreview


# --- Méthodes Publiques ---

# 🔹 Configure l'apparence du slot en fonction d'un pet, de son type et de son statut "découvert".
func setup(pet_name: String, type_info: Dictionary, is_discovered: bool):
	if is_discovered:
		pet_name_label.text = pet_name
		icon_rect.texture = PetIconCache.get_icon(pet_name, type_info)
		return
	pet_name_label.text = "???"
	icon_rect.texture = PetIconCache.get_icon(pet_name, {}, true)
