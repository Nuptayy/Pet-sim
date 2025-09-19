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
	%TotalCoinsLabel.text = str(int(DataManager.total_coins_earned))
	%TotalGemsLabel.text = str(DataManager.total_gems_earned)
	%CoinsPerSecondLabel.text = "%.2f/s" % DataManager.get_coins_per_second()
	
	# Pet le plus rare
	var rarest_pet = DataManager.get_rarest_pet_owned()
	if not rarest_pet.is_empty():
		var combined_chance = DataManager.get_combined_chance(rarest_pet)
		var pet_text = "%s (%s)" % [rarest_pet["base_name"], rarest_pet["type"]["name"]]
		var chance_text = "(%s)" % format_chance(combined_chance)
		%RarestPetLabel.text = "%s\n%s" % [pet_text, chance_text]
	else:
		%RarestPetLabel.text = "N/A"
	
	# Économie
	%CoinsPerSecondLabel.text = "%.2f/s" % DataManager.get_coins_per_second()
	%GemsPerSecondLabel.text = "%.4f%%/s" % DataManager.get_gems_per_second_chance()
	
	# Index
	%IndexCompletionLabel.text = "%.1f%%" % DataManager.get_index_completion()

# 🔹 Ajout d'une fonction de formatage dans ce script aussi.
func format_chance(chance_percent: float) -> String:
	if chance_percent <= 0:
		return "∞"
	
	if chance_percent >= 1.0:
		# "%.2f" pour garder deux décimales, "%%" pour afficher le caractère '%'.
		return "%.2f%%" % chance_percent
	
	var denominator = 1.0 / (chance_percent / 100.0)
	
	if denominator >= 1_000_000_000_000.0:
		return "1 in %.1fT" % (denominator / 1_000_000_000_000.0)
	
	elif denominator >= 1_000_000_000.0:
		return "1 in %.1fB" % (denominator / 1_000_000_000.0)
	
	elif denominator >= 1_000_000.0:
		return "1 in %.1fM" % (denominator / 1_000_000.0)
	
	elif denominator >= 1_000.0:
		return "1 in %.1fK" % (denominator / 1_000.0)
	
	else:
		return "1 in %d" % round(denominator)
