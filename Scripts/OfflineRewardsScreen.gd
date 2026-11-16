# OfflineRewardsScreen.gd
extends PanelContainer

# --- Signaux ---
signal rewards_claimed

# --- Constantes ---
const PET_SLOT_SCENE = preload("res://Scenes/PetSlot.tscn")
const PET_SECTION_TITLE_PATH = "MarginContainer/VBoxContainer/Label"


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Connecte le bouton de réclamation.
func _ready():
	%ClaimButton.pressed.connect(_on_claim_pressed)


# --- Méthodes Publiques ---

# 🔹 Configure l'écran avec les récompenses calculées par le backend.
func setup(rewards: Dictionary):
	%CoinsLabel.text = "Pièces gagnées : +%d" % rewards.net_coin_gain
	%GemsLabel.text = "Gemmes gagnées : +%d" % rewards.earned_gems
	%EggsLabel.text = "Œufs ouverts : %d" % rewards.eggs_hatched
	if rewards.best_pets_for_display.is_empty():
		var pet_section_title = get_node_or_null(PET_SECTION_TITLE_PATH)
		if pet_section_title:
			pet_section_title.hide()
		%PetDisplayBox.hide()
		return
	for pet_data in rewards.best_pets_for_display:
		var slot = PET_SLOT_SCENE.instantiate()
		%PetDisplayBox.add_child(slot)
		slot.setup({"base_name": pet_data.base_name, "type": pet_data.type})
		slot.focus_mode = Control.FOCUS_NONE
		slot.tooltip_text = ""


# --- Fonctions de Rappel (Signal Callbacks) ---

# 🔹 Réclame les récompenses puis prévient le LoadingScreen qu'il peut continuer.
func _on_claim_pressed():
	%ClaimButton.disabled = true
	await Backend.claim_offline_rewards()
	rewards_claimed.emit()
	queue_free()
