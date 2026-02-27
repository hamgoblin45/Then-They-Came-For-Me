extends Control

@onready var hp_bar: ProgressBar = %HPBar
@onready var hp_value: Label = %HPValue
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var energy_value: Label = %EnergyValue
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var stamina_value: Label = %StaminaValue

@onready var action_bar: TextureProgressBar = %ActionProgressBar

# Testing vars
@onready var satiety_bar: ProgressBar = %SatietyBar


func _ready():
	EventBus.main_scene_loaded.emit() # This will actually be done in the main game scene instead of here, testing only
	EventBus.stat_changed.connect(_change_stat)
	EventBus.consume_progress.connect(_on_consume_progress)

	_set_hud()


func _set_hud():
	hp_bar.max_value = GameState.max_hp
	hp_bar.value = GameState.hp
	hp_value.text = "%s/%s" % [str(snapped(GameState.hp, 1)), str(snapped(GameState.max_hp, 1))]
	
	energy_bar.max_value = GameState.max_energy
	energy_bar.value = GameState.energy
	energy_value.text = str(snapped(GameState.energy,1))
	
	stamina_bar.max_value = GameState.energy
	stamina_bar.value = GameState.stamina
	stamina_value.text = str(snapped(GameState.stamina,1))
	
	# This is only for testing unless we decide to display satiety to player
	satiety_bar.value = GameState.satiety


# Should this go in a PlayerManager, stay here, or something else?
func _change_stat(_stat: String):
	_set_hud()

func _on_consume_progress(ratio: float):
	if ratio <= 0 or ratio >= 1.0:
		action_bar.visible = false
	else:
		action_bar.visible = true
		action_bar.value = ratio * 100
