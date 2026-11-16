# GemShop.gd
extends PanelContainer

# --- Constantes ---
const UPGRADE_PANEL_SCENE = preload("res://Scenes/UpgradePanel.tscn")

# --- État ---
var _upgrade_panels: Array = []


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Construit la liste des améliorations et connecte les signaux.
func _ready():
	%CloseButton.pressed.connect(hide)
	for upgrade_id in GameConfig.GEM_UPGRADES:
		var panel = UPGRADE_PANEL_SCENE.instantiate()
		%UpgradeList.add_child(panel)
		panel.setup(upgrade_id)
		panel.purchase_requested.connect(_on_purchase_requested)
		_upgrade_panels.append(panel)
	visibility_changed.connect(_refresh_display)
	DataManager.gems_updated.connect(_on_gems_updated)
	DataManager.upgrades_changed.connect(_refresh_display)


# --- Fonctions de Rappel (Signal Callbacks) ---

# 🔹 Rafraîchit le magasin quand le nombre de gems change.
func _on_gems_updated(_new_gem_count: int):
	_refresh_display()

# 🔹 Demande l'achat d'une amélioration au backend.
func _on_purchase_requested(upgrade_id: String):
	await Backend.buy_upgrade(upgrade_id)


# --- Méthodes Internes ---

# 🔹 Met à jour le nombre de gems et l'état de chaque amélioration, si le magasin est visible.
func _refresh_display():
	if not is_visible_in_tree():
		return
	%GemsLabel.text = "Gems: %d" % DataManager.gems
	for panel in _upgrade_panels:
		panel.refresh()
