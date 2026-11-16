# TeamSlot.gd
extends Button

# --- Signaux ---
signal slot_clicked(pet_instance)

# --- Constantes ---
const PetIconCache = preload("res://Scripts/PetIconCache.gd")
const EQUIPPED_STYLE = preload("res://style/equipped_style.tres")

# --- Références aux Nœuds ---
@onready var icon_rect: TextureRect = %PetIcon

# --- État ---
var _pet_instance


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Connecte le clic sur le slot.
func _ready():
	pressed.connect(_on_pressed)


# --- Méthodes Publiques ---

# 🔹 Configure le slot avec les données d'un pet ou le met en état "vide".
func setup(pet_instance_or_null):
	_pet_instance = pet_instance_or_null
	tooltip_text = ""
	icon_rect.texture = null
	if not (_pet_instance is Dictionary) or not GameConfig.PET_DEFINITIONS.has(_pet_instance.base_name):
		_pet_instance = null
		disabled = true
		if has_theme_stylebox_override("normal"):
			remove_theme_stylebox_override("normal")
		return
	disabled = false
	var stats = _pet_instance.stats
	tooltip_text = "%s (%s)\nCoins x%.1f  Luck x%.2f  Gems %.4f/s" % [
		_pet_instance.base_name, _pet_instance.type.name,
		stats.CoinBoost, stats.LuckBoost, stats.GemBoost
	]
	add_theme_stylebox_override("normal", EQUIPPED_STYLE)
	icon_rect.texture = PetIconCache.get_icon(_pet_instance.base_name, _pet_instance.type)


# --- Fonctions de Rappel (Signal Callbacks) ---

# 🔹 Signale le clic avec le pet contenu dans le slot.
func _on_pressed():
	if _pet_instance is Dictionary:
		slot_clicked.emit(_pet_instance)
