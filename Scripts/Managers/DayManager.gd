extends Node

func _ready():
	EventBus.end_day.connect(_on_end_day_normal)

func _on_end_day_normal():
	# 1. Disable player movement while falling asleep
	GameState.can_move = false 
	
	# FIX: Just await the function itself, because it already returns the signal!
	await DayTransition.fade_out_for_sleep()
	
	# 3. Process the math
	process_transition(false)

func process_transition(was_arrested: bool):
	print("DayManager: Processing Day Transition. Arrested: ", was_arrested)
	
	# --- STAT UPDATES ---
	if was_arrested:
		GameState.hp = 50.0
		GameState.energy = 50.0
		GameState.satiety = 50.0 
		_confiscate_inventory()
	else:
		GameState.hp = 100.0
		GameState.energy = 100.0
		GameState.satiety = 100.0 
	
	EventBus.stat_changed.emit("hp")
	EventBus.stat_changed.emit("energy")
	EventBus.stat_changed.emit("satiety")
	
	GameState.raid_in_progress = false
	
	# --- TELEPORT PLAYER ---
	var spawns = get_tree().get_nodes_in_group("bed_spawn")
	if spawns.size() > 0:
		var spawn = spawns[0]
		
		# Move the player
		GameState.player.global_position = spawn.global_position
		
		# CRITICAL FIX: The FPS Controller requires the body rotation to remain ZERO.
		# If the body rotates, the movement math breaks.
		GameState.player.global_rotation = Vector3.ZERO 
		
		# Apply the bed's rotation ONLY to the player's HEAD node
		if GameState.player.HEAD:
			GameState.player.HEAD.global_rotation.y = spawn.global_rotation.y
			GameState.player.HEAD.rotation.x = 0 # Look straight ahead
			
			# Clear any leftover mouse movement from before the teleport
			GameState.player.mouseInput = Vector2.ZERO 
	else:
		push_warning("DayManager: No node found in 'bed_spawn' group! Teleport failed.")

	# --- NOTIFY WORLD ---
	EventBus.day_changed.emit()

	# --- WAKE UP ---
	await get_tree().create_timer(1.0).timeout
	
	if GameState.get_flag("has_morning_report"):
		# Let the UI handle the fade-in via the "Wake Up" button
		GameState.set_flag("has_morning_report", false)
	else:
		# Normal wake up
		DayTransition.fade_in()
		GameState.can_move = true

func _confiscate_inventory():
	var inv = GameState.pockets_inventory
	if not inv: return
	
	for i in range(inv.slots.size()):
		if inv.slots[i] != null:
			inv.slots[i] = null
			EventBus.inventory_item_updated.emit(inv, i)
			
	print("DayManager: All player items confiscated.")
