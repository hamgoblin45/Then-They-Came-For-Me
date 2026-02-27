extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect
@onready var consequence_label: Label = %ConsequenceLabel
@onready var report_label: RichTextLabel = %ReportLabel
@onready var restart_button: Button = $VBoxContainer/RestartButton

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS 
	await get_tree().process_frame
	hide()
	color_rect.modulate.a = 0
	
	EventBus.player_arrested.connect(_on_arrested)
	EventBus.game_over.connect(_on_game_over)
	EventBus.show_morning_report.connect(_on_morning_report)
	restart_button.pressed.connect(_on_restart_pressed)

func _on_arrested(reason: String = "Unknown", details: String = ""):
	var full_report = "CHARGE: " + reason + "\n"
	if details != "":
		full_report += details + "\n\n"
	
	# Dynamically list what is about to be confiscated
	var confiscated_text = _get_confiscated_list()
	full_report += "CONFISCATED ITEMS:\n" + confiscated_text
	
	restart_button.text = "Serve Time (Next Day)"
	_trigger_consequence("YOU HAVE BEEN ARRESTED", full_report)

func _on_game_over(reason: String = "Treason against the Regime."):
	restart_button.text = "Restart Game"
	_trigger_consequence("GAME OVER", "CHARGE: " + reason + "\n\nSentence: Permanent Labor Camp.")

func _trigger_consequence(title_text: String, report_text: String = ""):
	show()
	consequence_label.show()
	restart_button.show()
	
	consequence_label.text = title_text
	
	# Show the report text if we provided it
	if report_label:
		if report_text != "":
			report_label.text = report_text
			report_label.show()
		else:
			report_label.hide()
	
	var tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 1.0, 2.0)
	
	get_tree().paused = true 
	call_deferred("_force_mouse_visible")

func _force_mouse_visible():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_morning_report(title: String, text: String):
	show()
	consequence_label.show()
	consequence_label.text = title
	
	if report_label:
		report_label.show()
		report_label.text = text
		
	restart_button.show()
	restart_button.text = "Wake Up"
	call_deferred("_force_mouse_visible")

func _on_restart_pressed():
	if restart_button.text == "Wake Up":
		# Just close the text and fade in
		consequence_label.hide()
		if report_label: report_label.hide()
		restart_button.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		GameState.can_move = true
		fade_in()
		return
	get_tree().paused = false
	
	if consequence_label.text == "GAME OVER":
		get_tree().reload_current_scene()
	else:
		consequence_label.hide()
		if report_label: report_label.hide()
		restart_button.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		DayManager.process_transition(true)

# Helper function to generate a text list of inventory items
func _get_confiscated_list() -> String:
	var inv = GameState.pockets_inventory
	if not inv or inv.slots.is_empty(): 
		return "None\n"
		
	var item_counts = {}
	
	for slot in inv.slots:
		if slot and slot.item_data:
			if item_counts.has(slot.item_data.name):
				item_counts[slot.item_data.name] += slot.quantity
			else:
				item_counts[slot.item_data.name] = slot.quantity
				
	if item_counts.is_empty(): 
		return "None\n"
		
	var list_string = ""
	for item_name in item_counts.keys():
		list_string += "- " + item_name + " (x" + str(item_counts[item_name]) + ")\n"
		
	return list_string

# --- NEW: FADE LOGIC FOR SLEEPING / WAKING ---

func fade_out_for_sleep(duration: float = 1.5) -> Signal:
	show()
	consequence_label.hide()
	restart_button.hide()
	
	var tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 1.0, duration)
	
	# This returns the actual Signal object that DayManager is awaiting
	return tween.finished

func fade_in(duration: float = 2.0):
	# Ensure text is hidden just in case
	consequence_label.hide()
	restart_button.hide()
	
	var tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 0.0, duration)
	tween.tween_callback(hide) # Deactivate layer when done
