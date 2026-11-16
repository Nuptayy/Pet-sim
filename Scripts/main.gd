# main.gd
extends Node

# --- Constantes ---
const NumberFormat = preload("res://Scripts/NumberFormat.gd")
const TOAST_VISIBLE_DURATION = 1.5
const TOAST_FADE_DURATION = 0.5

# --- Références aux Nœuds ---
@onready var hatching_screen: PanelContainer = %HatchingScreen
@onready var inventory_screen: PanelContainer = %InventoryScreen
@onready var index_screen: PanelContainer = %IndexScreen
@onready var gem_shop = %GemShop
@onready var pause_menu = %PauseMenu
@onready var hatching_logic: Node = %HatchingLogic
@onready var hatching_animation_scene: Node3D = %HatchingAnimation
@onready var debug_menu = %DebugMenu
@onready var coins_label: Label = %HatchingScreen.find_child("CoinsLabel", true)
@onready var gems_label: Label = %HatchingScreen.find_child("GemsLabel", true)
@onready var index_notification_badge = %HatchingScreen.find_child("NotificationBadge", true)

# --- État Interne ---
var _toast_label: Label
var _toast_tween: Tween


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Initialise la scène principale, connecte tous les systèmes et définit l'état de départ.
func _ready():
	Backend.start_session()
	hatching_logic.NumberOfEggMax = DataManager.get_hatch_max(hatching_logic.base_hatch_max)
	hatching_logic.camera = hatching_animation_scene.get_node("Camera3D")
	hatching_logic.egg_grid_container = hatching_animation_scene.get_node("EggGridContainer")
	hatching_logic.viewport_container = get_viewport()
	pause_menu.continue_game.connect(toggle_pause)
	pause_menu.return_to_main_menu.connect(on_return_to_main_menu)
	hatching_screen.hatch_requested.connect(on_hatch_requested)
	inventory_screen.close_requested.connect(func(): set_game_state("hatching"))
	index_screen.close_requested.connect(index_screen.hide)
	hatching_screen.get_node("%GemShopButton").pressed.connect(gem_shop.show)
	hatching_screen.get_node("%IndexButton").pressed.connect(index_screen.show)
	hatching_logic.animation_started.connect(func(): set_game_state("animating"))
	hatching_logic.animation_finished.connect(func(): set_game_state("hatching"))
	pause_menu.get_node("OptionsMenu").graphic_settings_changed.connect(apply_quality_setting)
	DataManager.gems_updated.connect(_update_hud_gems)
	DataManager.upgrades_changed.connect(_on_upgrades_changed)
	DataManager.index_status_changed.connect(_update_index_button_notification)
	DataManager.message_emitted.connect(_show_toast)
	_create_toast()
	_update_hud_coins()
	_update_hud_gems(DataManager.gems)
	_update_index_button_notification()
	apply_quality_setting(SaveManager.load_setting("display/quality_index", 2))
	_on_upgrades_changed()
	set_game_state("hatching")

# 🔹 Met à jour les éléments de l'UI qui changent à chaque frame, comme le compteur de pièces.
func _process(_delta: float):
	_update_hud_coins()

# 🔹 Gère les entrées clavier globales du joueur (pause, inventaire, raccourcis).
func _input(event: InputEvent):
	if Backend.is_debug_allowed() and event.is_action_pressed("toggle_debug_menu"):
		debug_menu.toggle_menu(not debug_menu.visible)
		return
	if event.is_action_pressed("ui_cancel"):
		if not debug_menu.visible:
			toggle_pause()
		return
	if get_tree().paused:
		return
	if event.is_action_pressed("toggle_inventory"):
		_toggle_inventory()
		return
	if event.is_action_pressed("toggle_auto") and hatching_logic.auto_hatch_enabled:
		hatching_logic.auto_hatch_enabled = false
		return
	if not hatching_screen.visible or hatching_logic.is_hatching:
		return
	var selected_egg = hatching_screen.get_selected_egg_name()
	if selected_egg.is_empty():
		return
	if event.is_action_pressed("hatch_one"):
		on_hatch_requested(selected_egg, 1)
	elif event.is_action_pressed("hatch_max"):
		on_hatch_requested(selected_egg, hatching_logic.NumberOfEggMax)
	elif event.is_action_pressed("toggle_auto"):
		on_hatch_requested(selected_egg, -1)

# 🔹 Gère les notifications du système d'exploitation, comme la fermeture de la fenêtre.
func _notification(what: int):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().set_meta("offline_rewards_calculated", false)
		SaveManager.save_all()
		get_tree().quit()


# --- Gestion de l'État du Jeu et de la Pause ---

# 🔹 Change l'état visuel du jeu en affichant/cachant les écrans appropriés.
func set_game_state(state_name: String):
	for screen in [hatching_screen, inventory_screen, hatching_animation_scene]:
		if not is_instance_valid(screen):
			continue
		screen.visible = false
		if screen is Control:
			screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match state_name:
		"hatching":
			hatching_screen.visible = true
			hatching_screen.mouse_filter = Control.MOUSE_FILTER_STOP
			set_subviewport_rendering(hatching_screen, true)
			set_subviewport_rendering(inventory_screen, false)
		"inventory":
			inventory_screen.visible = true
			inventory_screen.mouse_filter = Control.MOUSE_FILTER_STOP
			set_subviewport_rendering(hatching_screen, false)
			set_subviewport_rendering(inventory_screen, true)
		"animating":
			hatching_animation_scene.visible = true
			set_subviewport_rendering(hatching_screen, false)
			set_subviewport_rendering(inventory_screen, false)

# 🔹 Met en pause ou reprend le jeu et affiche/cache le menu de pause.
func toggle_pause():
	get_tree().paused = not get_tree().paused
	pause_menu.set_paused(get_tree().paused)

# 🔹 Gère le retour au menu principal depuis le menu pause.
func on_return_to_main_menu():
	hatching_logic.auto_hatch_enabled = false
	get_tree().paused = false
	get_tree().set_meta("offline_rewards_calculated", false)
	SaveManager.save_all()
	get_tree().change_scene_to_file("res://Scenes/Main_menu.tscn")

# 🔹 Ouvre ou ferme l'inventaire, sauf pendant une éclosion.
func _toggle_inventory():
	if hatching_logic.is_hatching or hatching_logic.auto_hatch_enabled:
		return
	if inventory_screen.visible:
		set_game_state("hatching")
	else:
		set_game_state("inventory")


# --- Fonctions de Rappel (Signal Callbacks) ---

# 🔹 Reçoit et transmet les demandes d'éclosion au système de logique.
func on_hatch_requested(egg_name: String, count: int):
	if hatching_logic.is_hatching:
		return
	hatching_logic.on_hatch_requested(egg_name, count)

# 🔹 Met à jour les éléments de jeu qui dépendent des améliorations permanentes.
func _on_upgrades_changed():
	hatching_logic.NumberOfEggMax = DataManager.get_hatch_max(hatching_logic.base_hatch_max)
	hatching_screen.setup(hatching_logic)


# --- Fonctions de Mise à Jour de l'UI et des Paramètres ---

# 🔹 Met à jour le label affichant le nombre de pièces du joueur.
func _update_hud_coins():
	if is_instance_valid(coins_label):
		coins_label.text = "Coins: %s" % NumberFormat.format_compact(DataManager.coins)

# 🔹 Met à jour le label affichant le nombre de gemmes du joueur.
func _update_hud_gems(new_total: int):
	if is_instance_valid(gems_label):
		gems_label.text = "Gems: %s" % NumberFormat.format_compact(new_total)

# 🔹 Applique les préréglages de qualité graphique au monde 3D.
func apply_quality_setting(index: int):
	var world_3d = get_viewport().world_3d
	if not world_3d:
		return
	var env: Environment = world_3d.environment
	if not env:
		return
	match index:
		0:
			env.ssao_enabled = false
			env.ssil_enabled = false
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		1:
			env.ssao_enabled = true
			env.ssil_enabled = false
			get_viewport().msaa_3d = Viewport.MSAA_2X
		2:
			env.ssao_enabled = true
			env.ssil_enabled = true
			get_viewport().msaa_3d = Viewport.MSAA_4X

# 🔹 Active ou désactive le rendu des SubViewports d'un nœud parent pour optimiser les performances.
func set_subviewport_rendering(parent_node: Node, is_enabled: bool):
	if not parent_node:
		return
	var update_mode = SubViewport.UPDATE_ALWAYS if is_enabled else SubViewport.UPDATE_DISABLED
	for viewport in parent_node.find_children("*", "SubViewport", true, false):
		viewport.set_update_mode(update_mode)

# 🔹 Affiche ou cache la notification sur le bouton de l'Index.
func _update_index_button_notification():
	index_notification_badge.visible = DataManager.has_index_reward_to_claim()


# --- Messages au Joueur ---

# 🔹 Crée le label qui affiche les messages courts en haut de l'écran.
func _create_toast():
	var toast_layer = CanvasLayer.new()
	toast_layer.layer = 50
	add_child(toast_layer)
	_toast_label = Label.new()
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 28)
	_toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast_label.add_theme_constant_override("outline_size", 8)
	_toast_label.modulate.a = 0.0
	toast_layer.add_child(_toast_label)
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_label.offset_top = 90.0
	_toast_label.offset_bottom = 90.0

# 🔹 Affiche un message court qui disparaît tout seul.
func _show_toast(text: String):
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_VISIBLE_DURATION)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, TOAST_FADE_DURATION)
