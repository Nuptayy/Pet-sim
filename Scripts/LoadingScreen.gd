# LoadingScreen.gd
extends Control

const OFFLINE_REWARDS_SCREEN = preload("res://Scenes/OfflineRewardsScreen.tscn")

func _ready():
	if get_tree().has_meta("offline_rewards_calculated") and get_tree().get_meta("offline_rewards_calculated"):
		_proceed_to_game()
		return
	
	await get_tree().process_frame
	
	print("--- LOADINGSCREEN --- Valeur de DataManager.coins AVANT simulation: ", DataManager.coins)
	
	var last_timestamp = SaveManager.load_session_timestamp()
	
	if last_timestamp == 0:
		get_tree().set_meta("offline_rewards_calculated", true)
		_proceed_to_game()
		return
		
	var current_timestamp = Time.get_unix_time_from_system()
	var elapsed_seconds = current_timestamp - last_timestamp
	
	if elapsed_seconds < 0: elapsed_seconds = 0
	
	var offline_rewards_unlocked = DataManager.upgrade_levels.get("offline_rewards", 0) > 0
	
	if not offline_rewards_unlocked or elapsed_seconds < 60:
		get_tree().set_meta("offline_rewards_calculated", true)
		_proceed_to_game()
		return
		
	# --- PARTIE FINALE ---
	var max_duration = DataManager.get_max_offline_duration_seconds()
	var offline_duration = min(elapsed_seconds, max_duration)
	
	%Label.text = "Calcul des récompenses hors ligne..."
	await get_tree().process_frame
	
	# Lance la simulation et récupère les résultats.
	var results = DataManager.simulate_offline_progress(offline_duration)
	
	# Marque la simulation comme effectuée pour ne pas la relancer.
	get_tree().set_meta("offline_rewards_calculated", true)
	
	# Si la simulation n'a rien donné (pas d'œuf cible, etc.), on passe au jeu.
	if results.is_empty() or results.eggs_hatched == 0:
		_proceed_to_game()
	else:
		_show_results_screen(results)

# 🔹 Affiche l'écran des récompenses.
func _show_results_screen(results: Dictionary):
	var screen = OFFLINE_REWARDS_SCREEN.instantiate()
	add_child(screen)
	screen.setup(results)
	# Le "await screen.rewards_claimed" est crucial, il met en pause le chargement
	# jusqu'à ce que le joueur clique sur "Réclamer".
	await screen.rewards_claimed
	_proceed_to_game()

# 🔹 Lance la scène de jeu principale.
func _proceed_to_game():
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")
