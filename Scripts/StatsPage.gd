# StatsPage.gd
extends PanelContainer

# --- Signaux ---
signal back_pressed


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Initialise la page en connectant les signaux de base.
func _ready():
	%BackButton.pressed.connect(func(): back_pressed.emit())
	visibility_changed.connect(_on_visibility_changed)


# --- Fonctions de Rappel (Signal Callbacks) ---

# 🔹 Déclenche la mise à jour des statistiques lorsque la page devient visible.
func _on_visibility_changed():
	if visible:
		_update_all_stats()


# --- Méthodes de Mise à Jour de l'UI ---

# 🔹 Appelle toutes les fonctions de mise à jour pour rafraîchir l'ensemble de la page.
func _update_all_stats():
	_update_general_stats()
	_update_economy_stats()
	_update_rarest_pet_stat()
	_update_index_stat()

# 🔹 Met à jour les statistiques de progression générale (temps de jeu, œufs).
func _update_general_stats():
	%TimePlayedLabel.text = _format_seconds_to_hms(DataManager.time_played)
	%EggsHatchedLabel.text = str(DataManager.eggs_hatched)
	%CurrentLuckLabel.text = "x%.2f" % DataManager.get_total_luck_boost()
	%HatchSpeedLabel.text = "x%.2f" % DataManager.get_total_speed_boost()

# 🔹 Met à jour les statistiques économiques (monnaies gagnées et taux).
func _update_economy_stats():
	%TotalCoinsLabel.text = str(int(DataManager.total_coins_earned))
	%TotalGemsLabel.text = str(DataManager.total_gems_earned)
	%CoinsPerSecondLabel.text = "%.2f/s" % DataManager.get_coins_per_second()
	%GemsPerSecondLabel.text = "%.4f%%/s" % DataManager.get_gems_per_second_chance()

# 🔹 Met à jour l'affichage du pet le plus rare possédé par le joueur.
func _update_rarest_pet_stat():
	var rarest_pet = DataManager.get_rarest_pet_owned()
	if not rarest_pet.is_empty():
		var combined_chance = DataManager.get_combined_chance(rarest_pet)
		var pet_text = "%s (%s)" % [rarest_pet.base_name, rarest_pet.type.name]
		var chance_text = "(%s)" % _format_chance(combined_chance)
		%RarestPetLabel.text = "%s\n%s" % [pet_text, chance_text]
	else:
		%RarestPetLabel.text = "N/A"

# 🔹 Met à jour le pourcentage de complétion de l'index des pets.
func _update_index_stat():
	%IndexCompletionLabel.text = "%.1f%%" % DataManager.get_index_completion()


# --- Fonctions Utilitaires ---

# 🔹 Formate un nombre de secondes en une chaîne de caractères "HH:MM:SS".
func _format_seconds_to_hms(seconds: int) -> String:
	var h = seconds / 3600.0
	var m = (seconds % 3600) / 60.0
	var s = seconds % 60
	return "%02d:%02d:%02d" % [h, m, s]

# 🔹 Formate un pourcentage de chance en une chaîne de caractères lisible (ex: "1 in 1.5M").
# TODO: Cette fonction est dupliquée dans InventoryScreen.gd. Envisager de la déplacer
# dans un Autoload "FormatUtils.gd" pour éviter la redondance.
func _format_chance(chance_percent: float) -> String:
	if chance_percent <= 0.000001:
		return "1 in ∞"
	if chance_percent >= 1.0:
		return "%.2f%%" % chance_percent
	
	var denominator = 1.0 / (chance_percent / 100.0)
	
	if denominator >= 1_000_000_000_000.0: return "1 in %.1fT" % (denominator / 1_000_000_000_000.0)
	if denominator >= 1_000_000_000.0:   return "1 in %.1fB" % (denominator / 1_000_000_000.0)
	if denominator >= 1_000_000.0:       return "1 in %.1fM" % (denominator / 1_000_000.0)
	if denominator >= 1_000.0:           return "1 in %.1fK" % (denominator / 1_000.0)
	return "1 in %d" % round(denominator)
