# GemShop.gd
extends PanelContainer

const UPGRADE_PANEL_SCENE = preload("res://Scenes/UpgradePanel.tscn")

# 🔹 Initialise le magasin en connectant les signaux et en construisant la liste.
func _ready():
	%CloseButton.pressed.connect(hide)
	
	# Met à jour l'affichage à chaque changement pour rester synchronisé.
	visibility_changed.connect(_on_visibility_changed)
	DataManager.gems_updated.connect(_update_display)
	
# 🔹 Met à jour l'affichage complet du magasin lorsqu'il devient visible.
func _on_visibility_changed():
	if visible:
		_update_display()
		
# 🔹 Rafraîchit le nombre de gems et la liste des améliorations.
func _update_display():
	%GemsLabel.text = "Gems: %d" % DataManager.gems
	
	# Nettoie l'ancienne liste.
	for child in %UpgradeList.get_children():
		child.queue_free()
		
	# Reconstruit la liste à partir des données de DataManager.
	for upgrade_id in DataManager.GEM_UPGRADES:
		var panel = UPGRADE_PANEL_SCENE.instantiate()
		%UpgradeList.add_child(panel)
		panel.setup(upgrade_id)
		panel.purchase_requested.connect(_on_purchase_requested)

# 🔹 Gère une demande d'achat en appelant DataManager.
func _on_purchase_requested(upgrade_id: String):
	var success = DataManager.purchase_upgrade(upgrade_id)
	if success:
		# Si l'achat réussit, on met à jour l'affichage pour refléter
		# les nouveaux coûts et niveaux.
		_update_display()
