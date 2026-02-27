extends CanvasLayer

@onready var main_panel: VBoxContainer = $MarginContainer/MainPanel
@onready var options_panel: VBoxContainer = $MarginContainer/OptionsPanel

@onready var resume_btn: Button = $MarginContainer/MainPanel/ResumeButton
@onready var options_btn: Button = $MarginContainer/MainPanel/OptionsButton
@onready var quit_hub_btn: Button = $MarginContainer/MainPanel/QuitToMenuButton
@onready var quit_desktop_btn: Button = $MarginContainer/MainPanel/QuitToDesktopButton

@onready var master_volume_slider: HSlider = $MarginContainer/OptionsPanel/MasterVolumeSlider
@onready var back_btn: Button = $MarginContainer/OptionsPanel/BackButton

func _ready() -> void:
	hide()
	
	# Connect Button Signals
	resume_btn.pressed.connect(_unpause_game)
	options_btn.pressed.connect(_show_options)
	quit_hub_btn.pressed.connect(_quit_to_hub)
	quit_desktop_btn.pressed.connect(_quit_to_desktop)
	
	back_btn.pressed.connect(_show_main)
	master_volume_slider.value_changed.connect(_on_volume_changed)
	
	# Listen to the global EventBus
	EventBus.set_paused.connect(_on_pause_toggled)

func _unhandled_input(event: InputEvent) -> void:
	# "ui_cancel" is usually mapped to Escape by default in Godot
	if event.is_action_pressed("ui_cancel"):
		# Prevent pausing if we are in critical un-interruptible states
		if GameState.in_dialogue: return 
		
		# Toggle the pause state
		var new_pause_state = !get_tree().paused
		EventBus.set_paused.emit(new_pause_state)

func _on_pause_toggled(is_paused: bool) -> void:
	GameState.paused = is_paused
	
	if is_paused:
		show()
		_show_main()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		AudioManager.play_2d("ui_click") # Optional: Add a UI sound!
	else:
		hide()
		# Only recapture the mouse if we aren't shopping or looking at inventory
		if not GameState.ui_open and not GameState.shopping:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unpause_game() -> void:
	AudioManager.play_2d("ui_click")
	EventBus.set_paused.emit(false)

# --- PANEL NAVIGATION ---
func _show_options() -> void:
	AudioManager.play_2d("ui_click")
	main_panel.hide()
	options_panel.show()

func _show_main() -> void:
	AudioManager.play_2d("ui_click")
	options_panel.hide()
	main_panel.show()

# --- OPTIONS LOGIC ---
func _on_volume_changed(value: float) -> void:
	# Convert the linear slider value (0.0 to 1.0) to Godot's audio Decibels
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)

# --- QUIT LOGIC ---
func _quit_to_hub() -> void:
	# Clean up state before leaving
	EventBus.set_paused.emit(false) 
	get_tree().change_scene_to_file("res://TestingHub.tscn") # Adjust path if needed!

func _quit_to_desktop() -> void:
	get_tree().quit()
