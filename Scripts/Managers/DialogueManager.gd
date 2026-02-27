extends Node
# Used to call functions across the game from dialogue, especially Objectives and score adjustments (Suspicion, resistance, etc)

signal dialogue_ended
signal dialogue_started
signal interrogation_started
signal dialogue_choice_selected(choice_id: String)

func _ready():
	Dialogic.signal_event.connect(_on_dialogic_signal)
	Dialogic.timeline_ended.connect(_on_timeline_ended)


func start_dialogue(timeline_key: String, npc: NPC, npc_name: String = ""):
	if Dialogic.current_timeline != null: 
		print("DialogueManager ERROR: Cannot start '%s', timeline '%s' is already active!" % [timeline_key, Dialogic.current_timeline])
		return
	
	if npc_name != "":
		Dialogic.VAR.CurrentNPC = npc_name
	
	if npc:
		GameState.talking_to = npc
		
	print("DialogueManager: Starting dialogue timeline: ", timeline_key)
	Dialogic.start(timeline_key)
	
	get_viewport().set_input_as_handled()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.in_dialogue = true
	GameState.can_move = false
	
	# NEW: Trigger the cinematic focus!
	if GameState.player and is_instance_valid(GameState.talking_to):
		GameState.player.start_cinematic_focus(GameState.talking_to, 35.0)
		
	dialogue_started.emit()

func _on_timeline_ended():
	GameState.in_dialogue = false
	GameState.can_move = true
	
	# NEW: End the cinematic focus!
	if GameState.player:
		GameState.player.end_cinematic_focus()
	
	if not GameState.shopping:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	dialogue_ended.emit()

# This is used to confirm player has an objective before show a particular dialogue branch
func is_objective_complete(id: String) -> bool:
	for obj in GameState.objectives:
		if obj.id == id:
			return obj.complete
	return false


func _on_dialogic_signal(arg: Dictionary):
	match arg["signal_name"]:
		"follow_player":
			EventBus.follow_player.emit(GameState.talking_to, true)
		"choice_selected":
			dialogue_choice_selected.emit(arg["choice_id"])
		"open_shop":
			if arg["shop_inventory"]:
				var inv = load(arg["shop_inventory"])
				EventBus.open_specific_shop.emit(inv, false)
		#"visitor_leave":
			#EventBus.visitor_leave_requested.emit()
