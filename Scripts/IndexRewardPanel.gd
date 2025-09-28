# IndexRewardPanel.gd
extends VBoxContainer

signal claim_requested(egg_name)

var _egg_name: String

# 🔹 Configure le panneau avec les infos de récompense d'un œuf.
func setup(egg_name: String):
	_egg_name = egg_name
	
	var egg_def = DataManager.EGG_DEFINITIONS.filter(func(e): return e.name == egg_name).front()
	if not egg_def or not egg_def.has("reward"):
		hide() # Cache le panneau s'il n'y a pas de récompense définie.
		return

	var reward = egg_def.reward
	%RewardLabel.text = "Récompense: %d %s" % [reward.value, reward.type.capitalize()]
	
	var status = DataManager.egg_index_status.get(egg_name, "not_completed")
	
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
	%ClaimButton.pressed.connect(func(): claim_requested.emit(_egg_name))
