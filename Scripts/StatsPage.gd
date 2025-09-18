# StatsPage.gd
extends PanelContainer

signal back_pressed

func _ready():
	%BackButton.pressed.connect(func(): back_pressed.emit())
	
	# Se connecte au signal de visibilité pour se mettre à jour uniquement quand on l'ouvre.
	visibility_changed.connect(_on_visibility_changed)
	
func _on_visibility_changed():
	if visible:
		update_all_stats()

func update_all_stats():
	# Temps de jeu
	var total_seconds = DataManager.time_played
	%TimePlayedLabel.text = "%02d:%02d:%02d" % [total_seconds / 3600, (total_seconds % 3600) / 60, total_seconds % 60]
	
	# Œufs ouverts
	%EggsHatchedLabel.text = str(DataManager.eggs_hatched)
	
	# Luck
	%CurrentLuckLabel.text = "x%.2f" % DataManager.get_total_luck_boost()
	
	# Vitesse
	%HatchSpeedLabel.text = "%.2f s" % (1.0 / DataManager.get_total_speed_boost())
	
	# Monnaies
	%TotalCoinsLabel.text = str(DataManager.total_coins_earned)
	%TotalGemsLabel.text = str(DataManager.total_gems_earned)
	
	# Pet le plus rare
	var rarest = DataManager.get_rarest_pet_owned()
	if not rarest.is_empty():
		%RarestPetLabel.text = "%s (%s)" % [rarest["base_name"], rarest["type"]["name"]]
	else:
		%RarestPetLabel.text = "N/A"
	
	# Économie
	%CoinsPerSecondLabel.text = "%.2f/s" % DataManager.get_coins_per_second()
	%GemsPerSecondLabel.text = "%.4f%%/s" % DataManager.get_gems_per_second_chance()
	
	# Index
	%IndexCompletionLabel.text = "%.1f%%" % DataManager.get_index_completion()
