extends Control

@onready var time_input: SpinBox = $MarginContainer/VBoxContainer/GridContainer/TimeInput
@onready var suspicion_input: SpinBox = $MarginContainer/VBoxContainer/GridContainer/SuspicionInput
@onready var money_input: SpinBox = $MarginContainer/VBoxContainer/GridContainer/MoneyInput
@onready var fugitive_check: CheckBox = $MarginContainer/VBoxContainer/GridContainer/GuestCheck
@onready var raid_check: CheckBox = $MarginContainer/VBoxContainer/GridContainer/ForceRaidCheck
@onready var launch_button: Button = $MarginContainer/VBoxContainer/LaunchButton


var main_level_path: String = "res://Map/main_map.tscn"

func _ready() -> void:
	launch_button.pressed.connect(_on_launch_pressed)
	
	# Release the mouse in case we quit to menu from a captured state
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false

func _on_launch_pressed() -> void:
	print("TestingHub: Compiling GameState and Launching...")
	
	# 1. Apply Stats
	# Because TimeManager uses day_start on ready, we override it here!
	GameState.day_start = time_input.value 
	GameState.regime_suspicion = suspicion_input.value
	GameState.money = money_input.value
	
	# 2. Apply Special Flags
	GameState.set_flag("debug_start_with_fugitive", fugitive_check.button_pressed)
	
	if raid_check.button_pressed:
		GameState.set_flag("betrayed_by_guest", true) # This will force VisitorManager to schedule a raid
		
	# 3. Load the Game!
	get_tree().change_scene_to_file(main_level_path)
