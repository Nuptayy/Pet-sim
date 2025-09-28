# IndexRewardPanel.gd
extends VBoxContainer

signal claim_requested(egg_name, type_name)

var _egg_name: String
var _type_name: String

# 🔹 Configure le panneau avec les infos de récompense d'un œuf.
func setup(egg_name: String, type_name: String):
	_egg_name = egg_name
	_type_name = type_name
	
	var egg_def_array = DataManager.EGG_DEFINITIONS.filter(func(e): return e.name == egg_name)
	if egg_def_array.is_empty(): hide(); return
	var egg_def = egg_def_array.front()

	if not egg_def.has("rewards") or not egg_def.rewards.has(type_name):
		hide()
		return

	var reward = egg_def.rewards[type_name]
	%RewardLabel.text = "Récompense: %d %s" % [reward.value, reward.type.capitalize()]
	
	var status = "not_completed"
	var egg_statuses = DataManager.egg_index_status.get(egg_name)

# On vérifie si la donnée est bien un dictionnaire avant de l'utiliser.
	if typeof(egg_statuses) == TYPE_DICTIONARY and egg_statuses.has(type_name):
		status = egg_statuses[type_name]
	
	match status:
		"not_completed":
			%ClaimButton.text = "À compléter"
			%ClaimButton.disabled = true
		"ready_to_claim":
			%ClaimButton.text = "Réclamer !"
			%ClaimButton.disabled = false
		"claimed":
			%ClaimButton.text = "Réclamé"
			%ClaimButton.disabled = true

# 🔹 Connecte le signal du bouton.
func _ready():
	%ClaimButton.pressed.connect(func(): claim_requested.emit(_egg_name, _type_name))
