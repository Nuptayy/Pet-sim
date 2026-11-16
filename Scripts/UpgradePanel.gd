# UpgradePanel.gd
extends PanelContainer

# --- Signaux ---
signal purchase_requested(upgrade_id)

# --- État ---
var _upgrade_id: String


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Connecte le bouton d'achat au signal.
func _ready():
	%BuyButton.pressed.connect(func(): purchase_requested.emit(_upgrade_id))


# --- Méthodes Publiques ---

# 🔹 Configure le panneau avec les données d'une amélioration spécifique.
func setup(upgrade_id: String):
	_upgrade_id = upgrade_id
	var upgrade_def = GameConfig.GEM_UPGRADES[upgrade_id]
	%UpgradeNameLabel.text = upgrade_def.name
	tooltip_text = upgrade_def.description
	refresh()

# 🔹 Met à jour le niveau, le coût et l'état du bouton d'achat.
func refresh():
	if not GameConfig.GEM_UPGRADES.has(_upgrade_id):
		return
	var max_level = GameConfig.GEM_UPGRADES[_upgrade_id].max_level
	var current_level = DataManager.get_upgrade_level(_upgrade_id)
	if GameConfig.is_upgrade_maxed(_upgrade_id, current_level):
		%LevelLabel.text = "Niveau MAX"
		%BuyButton.text = "MAX"
		%BuyButton.disabled = true
		return
	var cost = DataManager.get_upgrade_cost(_upgrade_id)
	%LevelLabel.text = "Niv. %d / %s" % [current_level, "∞" if max_level == -1 else str(max_level)]
	%BuyButton.text = "Coût: %d G" % cost
	%BuyButton.disabled = DataManager.gems < cost
