# UpgradePanel.gd
extends PanelContainer

signal purchase_requested(upgrade_id)

var _upgrade_id: String

# 🔹 Configure le panneau avec les données d'une amélioration spécifique.
func setup(upgrade_id: String):
	self._upgrade_id = upgrade_id
	
	var upgrade_def = DataManager.GEM_UPGRADES[upgrade_id]
	var current_level = DataManager.upgrade_levels.get(upgrade_id, 0)
	
	%UpgradeNameLabel.text = upgrade_def.name
	
	self.tooltip_text = upgrade_def.description 
	
	# Calcule le coût du prochain niveau.
	var cost = int(upgrade_def.base_cost * pow(upgrade_def.cost_increase_factor, current_level))
	
	# Gère l'affichage si le niveau max est atteint.
	if upgrade_def.max_level != -1 and current_level >= upgrade_def.max_level:
		%LevelLabel.text = "Niveau MAX"
		%BuyButton.text = "MAX"
		%BuyButton.disabled = true
	else:
		var max_level_text = "∞" if upgrade_def.max_level == -1 else str(upgrade_def.max_level)
		%LevelLabel.text = "Niv. %d / %s" % [current_level, max_level_text]
		%BuyButton.text = "Coût: %d G" % cost
		%BuyButton.disabled = DataManager.gems < cost # Désactive si pas assez de gems.

# 🔹 Connecte le bouton d'achat au signal.
func _ready():
	%BuyButton.pressed.connect(func(): purchase_requested.emit(_upgrade_id))
