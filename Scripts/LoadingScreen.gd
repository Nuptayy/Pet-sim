# LoadingScreen.gd
extends Control

# --- Constantes ---
const OFFLINE_REWARDS_SCREEN = preload("res://Scenes/OfflineRewardsScreen.tscn")


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Récupère les récompenses hors ligne une seule fois par session, puis lance le jeu.
func _ready():
	if get_tree().get_meta("offline_rewards_calculated", false):
		_proceed_to_game()
		return
	await get_tree().process_frame
	get_tree().set_meta("offline_rewards_calculated", true)
	%Label.text = "Calcul des récompenses hors ligne..."
	await get_tree().process_frame
	var result = await Backend.get_pending_offline_rewards()
	if result.ok and result.has_rewards:
		_show_results_screen(result.rewards)
	else:
		_proceed_to_game()


# --- Méthodes Internes ---

# 🔹 Affiche l'écran des récompenses et attend que le joueur les réclame.
func _show_results_screen(rewards: Dictionary):
	var screen = OFFLINE_REWARDS_SCREEN.instantiate()
	add_child(screen)
	screen.setup(rewards)
	await screen.rewards_claimed
	_proceed_to_game()

# 🔹 Lance la scène de jeu principale.
func _proceed_to_game():
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")
