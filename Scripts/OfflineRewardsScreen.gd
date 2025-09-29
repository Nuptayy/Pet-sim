# OfflineRewardsScreen.gd
extends PanelContainer

# Signal pour dire au LoadingScreen que le joueur a cliqué et qu'on peut continuer.
signal rewards_claimed

const PET_SLOT_SCENE = preload("res://Scenes/PetSlot.tscn")

var _results: Dictionary

# 🔹 Configure l'écran avec les résultats de la simulation.
func setup(results: Dictionary):
	_results = results
	
	%CoinsLabel.text = "Pièces gagnées : +%d" % results.net_coin_gain
	
	%GemsLabel.text = "Gemmes gagnées : +%d" % results.earned_gems
	%EggsLabel.text = "Œufs ouverts : %d" % results.eggs_hatched
	
	if results.best_pets_for_display.is_empty():
		# On cherche le parent du HBox pour le cacher, qui est probablement un VBox.
		var pet_section_title = find_child("Meilleurs pets trouvés :", true, false)
		if pet_section_title: pet_section_title.hide()
		%PetDisplayBox.hide()
	else:
		for pet_data in results.best_pets_for_display:
			var slot = PET_SLOT_SCENE.instantiate()
			%PetDisplayBox.add_child(slot)
			
			var display_instance = {
				"base_name": pet_data.base_name,
				"type": pet_data.type,
				"unique_id": -1,
			}
			slot.setup(display_instance)
			slot.focus_mode = Control.FOCUS_NONE
			slot.tooltip_text = ""

# 🔹 Connecte le bouton de réclamation.
func _ready():
	%ClaimButton.pressed.connect(_on_claim_pressed)

# 🔹 Gère le clic sur "Réclamer".
func _on_claim_pressed():
	# Appelle la fonction dans DataManager pour appliquer réellement les gains.
	DataManager.apply_offline_gains(_results)
	
	# Émet le signal pour que le LoadingScreen sache qu'il peut continuer.
	rewards_claimed.emit()
	queue_free()
