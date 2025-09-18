# OptionsMenu.gd
extends PanelContainer

# 🔹 Signal pour informer le parent (le PauseMenu) de se fermer.
signal back_pressed
signal graphic_settings_changed(quality_index)

# 🔹 Références aux nœuds de l'interface.
@onready var resolution_button: OptionButton = %ResolutionButton
@onready var fullscreen_checkbox: CheckBox = %FullscreenCheckbox
@onready var quality_button: OptionButton = %QualityButton
@onready var vsync_checkbox: CheckBox = %VsyncCheckbox
@onready var fps_limit_button: OptionButton = %FpsLimitButton
@onready var confirm_delete_checkbox: CheckBox = %ConfirmDeleteCheckbox
@onready var back_button: Button = %BackButton

# 🔹 Dictionnaire pour stocker les résolutions supportées.
const RESOLUTIONS = {
	"1280x720": Vector2i(1280, 720),
	"1920x1080": Vector2i(1920, 1080),
	"2560x1440": Vector2i(2560, 1440),
	"3840x2160": Vector2i(3840, 2160)
}

# 🔹 Initialisation du menu.
func _ready():
	populate_resolution_button()
	populate_quality_button()
	populate_fps_limit_button()

	load_settings()

	resolution_button.item_selected.connect(on_resolution_changed)
	fullscreen_checkbox.toggled.connect(on_fullscreen_toggled)
	quality_button.item_selected.connect(on_quality_changed)
	vsync_checkbox.toggled.connect(on_vsync_toggled)
	fps_limit_button.item_selected.connect(on_fps_limit_changed)
	confirm_delete_checkbox.toggled.connect(on_confirm_delete_toggled)
	
	back_button.pressed.connect(func(): back_pressed.emit())

# --- Fonctions de Remplissage des Menus ---

func populate_resolution_button():
	for text in RESOLUTIONS:
		resolution_button.add_item(text)

func populate_quality_button():
	quality_button.add_item("Basse")
	quality_button.add_item("Moyenne")
	quality_button.add_item("Haute")

func populate_fps_limit_button():
	fps_limit_button.add_item("30")
	fps_limit_button.add_item("60")
	fps_limit_button.add_item("120")
	fps_limit_button.add_item("240")
	fps_limit_button.add_item("Illimité")

# --- Fonctions de Chargement et d'Application des Paramètres ---

# 🔹 Charge les paramètres actuels du jeu et met à jour l'UI.
func load_settings():
	await get_tree().process_frame
	var settings = SaveManager.current_settings
	
	# Résolution
	var current_res_text = "%dx%d" % [settings["resolution"].x, settings["resolution"].y]
	for i in range(resolution_button.item_count):
		if resolution_button.get_item_text(i) == current_res_text:
			resolution_button.select(i)
			break
	
	# Plein Écran
	fullscreen_checkbox.button_pressed = (settings["fullscreen_mode"] == Window.MODE_FULLSCREEN)
	
	# VSync
	vsync_checkbox.button_pressed = (settings["vsync_mode"] != DisplayServer.VSYNC_DISABLED)
	
	# Limite de FPS
	var fps_text = str(settings["fps_limit"])
	if settings["fps_limit"] == 0: fps_text = "Illimité"
	for i in range(fps_limit_button.item_count):
		if fps_limit_button.get_item_text(i) == fps_text:
			fps_limit_button.select(i)
			break

	# Qualité Graphique
	quality_button.select(settings["quality_index"])
	
	# Confirmation de suppression
	confirm_delete_checkbox.button_pressed = settings["confirm_delete"]

# --- Fonctions appelées par les signaux ---

func on_resolution_changed(index: int):
	var selected_text = resolution_button.get_item_text(index)
	var new_resolution = RESOLUTIONS[selected_text]
	get_window().size = new_resolution
	SaveManager.current_settings["resolution"] = new_resolution
	SaveManager.save_options()

func on_fullscreen_toggled(is_on: bool):
	var new_mode = Window.MODE_FULLSCREEN if is_on else Window.MODE_WINDOWED
	get_window().mode = new_mode
	SaveManager.current_settings["fullscreen_mode"] = new_mode
	SaveManager.save_options()

func on_quality_changed(index: int):
	SaveManager.current_settings["quality_index"] = index
	SaveManager.save_options()
	graphic_settings_changed.emit(index)
	print("Qualité changée à l'index (depuis OptionsMenu): ", index)

func on_vsync_toggled(is_on: bool):
	if is_on:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	SaveManager.save_options()

func on_fps_limit_changed(index: int):
	var selected_text = fps_limit_button.get_item_text(index)
	if selected_text == "Illimité":
		Engine.max_fps = 0
	else:
		Engine.max_fps = selected_text.to_int()
	SaveManager.save_options()

func on_confirm_delete_toggled(is_on: bool):
	SaveManager.current_settings["confirm_delete"] = is_on
	SaveManager.save_options()

# --- Fonctions d'Application ---

# 🔹 Applique les préréglages de qualité graphique.
func apply_quality_setting(index: int):
	var world_3d = get_viewport().world_3d
	if not world_3d:
		printerr("Impossible de trouver le World3D pour appliquer les paramètres de qualité.")
		return
		
	var env: Environment = world_3d.environment
	if not env:
		printerr("Aucun environnement n'est défini dans le World3D. Impossible d'appliquer les paramètres de qualité.")
		return

	match index:
		0: # Basse
			env.ssao_enabled = false
			env.ssil_enabled = false
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
			print("Qualité réglée sur : Basse")
		1: # Moyenne
			env.ssao_enabled = true
			env.ssil_enabled = false
			get_viewport().msaa_3d = Viewport.MSAA_2X
			print("Qualité réglée sur : Moyenne")
		2: # Haute
			env.ssao_enabled = true
			env.ssil_enabled = true
			get_viewport().msaa_3d = Viewport.MSAA_4X
			print("Qualité réglée sur : Haute")
