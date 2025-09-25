# OptionsMenu.gd
extends PanelContainer

# --- Signaux ---
signal back_pressed
signal graphic_settings_changed(quality_index)

# --- Constantes ---
const RESOLUTIONS = {
	"1280x720": Vector2i(1280, 720),
	"1920x1080": Vector2i(1920, 1080),
	"2560x1440": Vector2i(2560, 1440),
	"3840x2160": Vector2i(3840, 2160)
}

# --- Références aux Nœuds ---
@onready var resolution_button: OptionButton = %ResolutionButton
@onready var fullscreen_checkbox: CheckBox = %FullscreenCheckbox
@onready var quality_button: OptionButton = %QualityButton
@onready var vsync_checkbox: CheckBox = %VsyncCheckbox
@onready var fps_limit_button: OptionButton = %FpsLimitButton
@onready var confirm_delete_checkbox: CheckBox = %ConfirmDeleteCheckbox

# --- État ---
var _is_loading_settings = false # Verrou pour éviter les signaux au chargement


# --- Fonctions du Cycle de Vie Godot ---

# 🔹 Initialise le menu, remplit les listes d'options et connecte les signaux.
func _ready():
	_populate_option_buttons()
	_connect_signals()
	
	visibility_changed.connect(_on_visibility_changed)

# --- Fonctions de Rappel (Signal Callbacks) ---

# 🔹 Charge l'état actuel des paramètres lorsque le menu devient visible.
func _on_visibility_changed():
	if visible:
		_load_and_display_settings()

# 🔹 Modifie la résolution de la fenêtre.
func _on_resolution_changed(index: int):
	if _is_loading_settings: return
	var selected_text = resolution_button.get_item_text(index)
	var new_resolution = RESOLUTIONS[selected_text]
	
	get_window().size = new_resolution
	SaveManager.update_setting("display/resolution", new_resolution)

# 🔹 Bascule le mode plein écran.
func _on_fullscreen_toggled(is_on: bool):
	if _is_loading_settings: return
	var new_mode = Window.MODE_FULLSCREEN if is_on else Window.MODE_WINDOWED
	
	get_window().mode = new_mode
	SaveManager.update_setting("display/fullscreen_mode", new_mode)

# 🔹 Modifie le préréglage de qualité graphique.
func _on_quality_changed(index: int):
	if _is_loading_settings: return
	
	graphic_settings_changed.emit(index)
	SaveManager.update_setting("display/quality_index", index)

# 🔹 Active ou désactive la synchronisation verticale (VSync).
func _on_vsync_toggled(is_on: bool):
	if _is_loading_settings: return
	var new_mode = DisplayServer.VSYNC_ENABLED if is_on else DisplayServer.VSYNC_DISABLED
	
	DisplayServer.window_set_vsync_mode(new_mode)
	SaveManager.update_setting("display/vsync_mode", new_mode)

# 🔹 Modifie la limite de FPS du moteur.
func _on_fps_limit_changed(index: int):
	if _is_loading_settings: return
	var selected_text = fps_limit_button.get_item_text(index)
	var new_limit = 0
	if selected_text != "Illimité":
		new_limit = selected_text.to_int()
		
	Engine.max_fps = new_limit
	SaveManager.update_setting("display/fps_limit", new_limit)

# 🔹 Active ou désactive la confirmation avant de supprimer un pet.
func _on_confirm_delete_toggled(is_on: bool):
	if _is_loading_settings: return
	SaveManager.update_setting("gameplay/confirm_delete", is_on)


# --- Méthodes Internes ---

# 🔹 Remplit les listes déroulantes avec les options disponibles.
func _populate_option_buttons():
	for text in RESOLUTIONS:
		resolution_button.add_item(text)
	
	quality_button.add_item("Basse")
	quality_button.add_item("Moyenne")
	quality_button.add_item("Haute")
	
	fps_limit_button.add_item("30")
	fps_limit_button.add_item("60")
	fps_limit_button.add_item("120")
	fps_limit_button.add_item("240")
	fps_limit_button.add_item("Illimité")

# 🔹 Connecte les signaux de tous les contrôles de l'interface utilisateur.
func _connect_signals():
	resolution_button.item_selected.connect(_on_resolution_changed)
	fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)
	quality_button.item_selected.connect(_on_quality_changed)
	vsync_checkbox.toggled.connect(_on_vsync_toggled)
	fps_limit_button.item_selected.connect(_on_fps_limit_changed)
	confirm_delete_checkbox.toggled.connect(_on_confirm_delete_toggled)
	%BackButton.pressed.connect(func(): back_pressed.emit())

# 🔹 Lit les valeurs depuis SaveManager et met à jour l'interface.
func _load_and_display_settings():
	_is_loading_settings = true
	
	# Résolution
	var current_res = SaveManager.load_setting("display/resolution", Vector2i(1920, 1080))
	var current_res_text = "%dx%d" % [current_res.x, current_res.y]
	for i in range(resolution_button.item_count):
		if resolution_button.get_item_text(i) == current_res_text:
			resolution_button.select(i)
			break
	
	# Autres paramètres
	var fullscreen_mode = SaveManager.load_setting("display/fullscreen_mode", Window.MODE_WINDOWED)
	fullscreen_checkbox.button_pressed = (fullscreen_mode == Window.MODE_FULLSCREEN)
	
	var vsync_mode = SaveManager.load_setting("display/vsync_mode", DisplayServer.VSYNC_DISABLED)
	vsync_checkbox.button_pressed = (vsync_mode != DisplayServer.VSYNC_DISABLED)
	
	var fps_limit = SaveManager.load_setting("display/fps_limit", 0)
	var fps_text = "Illimité" if fps_limit == 0 else str(fps_limit)
	for i in range(fps_limit_button.item_count):
		if fps_limit_button.get_item_text(i) == fps_text:
			fps_limit_button.select(i)
			break
			
	quality_button.select(SaveManager.load_setting("display/quality_index", 2))
	confirm_delete_checkbox.button_pressed = SaveManager.load_setting("gameplay/confirm_delete", true)
	
	# Attend la fin de la frame avant de retirer le verrou pour éviter les faux positifs.
	await get_tree().process_frame
	_is_loading_settings = false
