extends Control

@onready var start_raid_button: Button = $TestHUD/StartRaid
@onready var satiety_bar: ProgressBar = %SatietyBar
@onready var suspicion_bar: ProgressBar = %SuspicionBar
@onready var resistance_bar: ProgressBar = %ResistanceBar

@onready var search_labels: VBoxContainer = $SearchLabels
@onready var patience_label: Label = $SearchLabels/PatienceLabel
@onready var thoroughness_label: Label = $SearchLabels/ThoroughnessLabel
@onready var search_suspicion_label: Label = $SearchLabels/SearchSuspicionLabel


func _ready() -> void:
	EventBus.stat_changed.connect(_on_stat_changed)
	EventBus.show_test_value.connect(_show_test_value)
	_on_stat_changed("satiety")
	_on_stat_changed("suspicion")
	_on_stat_changed("resistance")

func _on_start_raid_pressed() -> void:
	EventBus.raid_starting.emit()

func _on_stat_changed(stat: String):
	match stat:
		"satiety":
			satiety_bar.value = GameState.satiety
		"suspicion":
			suspicion_bar.value = GameState.regime_suspicion
		"resistance":
			resistance_bar.value = GameState.resistance


func _show_test_value(key: String, value: float):
	match key:
		"search_tesnsion":
			search_suspicion_label.text = "Searcher Tension: " + str(value) # Modifier to make getting caught more likely when moving items
			
		"patience":
			patience_label.text = "Patience: %s sec" % str(value) # How long they will search
		"thoroughness":
			thoroughness_label.text = "Thoroughness: " + str(value) # How hard the searcher will search (discovery chance)
