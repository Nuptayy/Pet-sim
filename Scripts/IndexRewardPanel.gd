# IndexRewardPanel.gd
extends VBoxContainer

# --- Signaux ---
signal claim_requested(egg_name, type_name)

# --- État ---
var _egg_name: String
var _type_name: String


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Connecte le signal du bouton.
func _ready():
	%ClaimButton.pressed.connect(func(): claim_requested.emit(_egg_name, _type_name))


# --- Méthodes Publiques ---

# 🔹 Configure le panneau avec les infos de récompense d'un œuf.
func setup(egg_name: String, type_name: String):
	_egg_name = egg_name
	_type_name = type_name
	var egg_def = GameConfig.get_egg_definition(egg_name)
	if egg_def.is_empty() or not egg_def.rewards.has(type_name):
		hide()
		return
	%RewardLabel.text = "Récompense: %s" % _format_reward(egg_def.rewards[type_name])
	match DataManager.get_index_status(egg_name, type_name):
		"ready_to_claim":
			%ClaimButton.text = "Réclamer !"
			%ClaimButton.disabled = false
		"claimed":
			%ClaimButton.text = "Réclamé"
			%ClaimButton.disabled = true
		_:
			%ClaimButton.text = "À compléter"
			%ClaimButton.disabled = true


# --- Méthodes Internes ---

# 🔹 Retourne le texte lisible d'une récompense selon son type.
func _format_reward(reward: Dictionary) -> String:
	match reward.type:
		"gems":
			return "%d Gems" % reward.value
		"coins":
			return "%d Coins" % reward.value
		"permanent_luck":
			return "+%s%% Luck permanente" % str(snappedf(reward.value * 100.0, 0.01))
	return "%s %s" % [reward.value, reward.type.capitalize()]
