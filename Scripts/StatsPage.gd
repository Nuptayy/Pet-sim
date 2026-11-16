# StatsPage.gd
extends PanelContainer

# --- Signaux ---
signal back_pressed

# --- Constantes ---
const NumberFormat = preload("res://Scripts/NumberFormat.gd")


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Connecte le bouton retour et le rafraîchissement à l'ouverture.
func _ready():
	%BackButton.pressed.connect(func(): back_pressed.emit())
	visibility_changed.connect(_on_visibility_changed)


# --- Fonctions de Rappel (Signal Callbacks) ---

# 🔹 Met à jour toutes les statistiques quand la page devient visible.
func _on_visibility_changed():
	if is_visible_in_tree():
		_update_all_stats()


# --- Méthodes Internes ---

# 🔹 Remplit tous les labels de la page avec l'état actuel du joueur.
func _update_all_stats():
	%TimePlayedLabel.text = NumberFormat.format_duration(DataManager.time_played)
	%EggsHatchedLabel.text = str(DataManager.eggs_hatched)
	%CurrentLuckLabel.text = "x%.2f" % DataManager.get_total_luck_boost()
	%HatchSpeedLabel.text = "x%.2f" % DataManager.get_total_speed_boost()
	%TotalCoinsLabel.text = NumberFormat.format_compact(DataManager.total_coins_earned)
	%TotalGemsLabel.text = NumberFormat.format_compact(DataManager.total_gems_earned)
	%CoinsPerSecondLabel.text = "%.2f/s" % DataManager.get_coins_per_second()
	%GemsPerSecondLabel.text = "%.4f/s" % DataManager.get_gems_per_second()
	%IndexCompletionLabel.text = "%.2f%%" % DataManager.get_index_completion()
	%RarestPetLabel.text = _get_rarest_pet_text()

# 🔹 Retourne le texte décrivant le pet le plus rare jamais obtenu.
func _get_rarest_pet_text() -> String:
	var rarest_pet = DataManager.rarest_pet_ever_owned
	if rarest_pet.is_empty():
		return "N/A"
	var chance_text = NumberFormat.format_chance(GameConfig.get_combined_chance(rarest_pet))
	return "%s (%s)\n%s" % [rarest_pet.base_name, rarest_pet.type.name, chance_text]
