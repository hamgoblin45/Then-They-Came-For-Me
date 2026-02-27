extends Control

@onready var raid_in_progress_label: Label = %RaidInProgressLabel
@onready var answer_door_timer_label: Label = %AnswerDoorTimerLabel
@onready var frisk_warning: Label = %FriskWarning

@onready var busted_label: Label = %BustedLabel
@onready var clear_label: Label = %ClearLabel

var pulse_tween: Tween

func _ready() -> void:
	EventBus.raid_starting.connect(_on_raid_starting)
	SearchManager.raid_finished.connect(_on_raid_finished)
	EventBus.raid_timer_updated.connect(_on_raid_timer_updated)
	EventBus.answering_door.connect(_on_door_answered)
	
	SearchManager.search_step_started.connect(_on_search_started)
	SearchManager.search_finished.connect(_on_search_finished)
	SearchManager.search_busted_visuals.connect(_on_search_busted) # NEW
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	
	EventBus.day_changed.connect(_on_day_changed)
	
	hide()
	frisk_warning.hide()
	if busted_label: busted_label.hide()
	if clear_label: clear_label.hide()

func _on_raid_starting():
	show()
	frisk_warning.hide()

func _on_search_started(inv: InventoryData, index: int, duration: float):
	if inv == GameState.pockets_inventory:
		show()
		frisk_warning.show()
		if not pulse_tween or not pulse_tween.is_valid():
			_start_pulsing()

func _start_pulsing():
	pulse_tween = create_tween().set_loops() 
	pulse_tween.tween_property(frisk_warning, "modulate:a", 0.2, 0.5)
	pulse_tween.tween_property(frisk_warning, "modulate:a", 1.0, 0.5)

# NEW: Trigger Busted label early
func _on_search_busted(index: int):
	_hide_warnings()
	if busted_label: 
		busted_label.show()

func _on_search_finished(caught: bool, item: ItemData, qty: int, index: int = -1):
	_hide_warnings()
	
	# Only show CLEAR if they searched and found absolutely nothing
	if not caught and item == null:
		if clear_label:
			clear_label.show()
			await get_tree().create_timer(1.5).timeout
			if clear_label: clear_label.hide()

func _on_dialogue_ended():
	if busted_label: 
		busted_label.hide()
	frisk_warning.hide()
	_hide_warnings()

func _on_raid_finished():
	hide()
	_hide_warnings()

func _on_raid_timer_updated(value: float):
	if value <= 1.0: hide()
	answer_door_timer_label.text = "ANSWER DOOR: %s SECONDS" % str(value)

func _on_door_answered():
	answer_door_timer_label.text = ""

func _hide_warnings():
	frisk_warning.hide()
	if pulse_tween:
		pulse_tween.kill()

func _on_day_changed():
	hide()
	_hide_warnings()
	if busted_label: busted_label.hide()
	if clear_label: clear_label.hide()
	answer_door_timer_label.text = ""
