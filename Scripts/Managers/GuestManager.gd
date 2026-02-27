extends Node

signal guest_added(npc_data: NPCData)
signal guest_removed(npc_data: NPCData)
signal guest_notification(message: String)

@export_group("Guest Assets")
@export var clue_prefabs: Array[PackedScene] # Assign your crumpled paper/dirty dish scenes here

var active_guests: Array[GuestNPC] = []
var idle_spots: Array[Node3D] = []

func _ready():
	await get_tree().process_frame
	_update_idle_spots()
	
	# Listen to time to trigger guest needs and messes
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.day_changed.connect(_on_day_changed)
	
	EventBus.raid_starting.connect(_trigger_raid_panic)

### TESTING
#func _input(event: InputEvent) -> void:
	## Press '1' to instantly ruin the guest's life
	#if event.is_action_pressed("debug_ruin_guest"): # Map this to '1' in Project Settings
		#for guest in active_guests:
			#guest.satiety = 0.0
			#guest.stress = 100.0
			#
			## Force loyalty to 0 so they hate you
			#if "loyalty" in guest.npc_data:
				#guest.npc_data.loyalty = 0.0 
				#
		#print("DEBUG: All guests are now starving, stressed, and disloyal!")
		#
	## Press '2' to instantly go to sleep
	#if event.is_action_pressed("debug_force_sleep"): # Map this to '2' in Project Settings
		#print("DEBUG: Forcing day transition!")
		#EventBus.end_day.emit()

func _update_idle_spots():
	idle_spots.assign(get_tree().get_nodes_in_group("guest_idle_spots"))

func make_guest(npc: NPC):
	print("GuestManager: %s is now a house guest!" % npc.npc_data.name)
	
	if npc.is_in_group("visitors"):
		npc.remove_from_group("visitors")
	if not npc.is_in_group("guests"):
		npc.add_to_group("guests")
		
	if npc is GuestNPC:
		npc.is_inside_house = true
		active_guests.append(npc)
		
	guest_added.emit(npc.npc_data)
	guest_notification.emit("%s is now hiding in your home." % npc.npc_data.name)
	
	send_to_random_spot(npc)

func send_to_random_spot(npc: NPC):
	if idle_spots.is_empty():
		_update_idle_spots()
	if idle_spots.is_empty(): return
		
	var spot = idle_spots.pick_random()
	npc.command_move_to(spot.global_position)
	await npc.destination_reached
	# npc.anim.play("idle_sitting")

# --- DAILY ROUTINE & CLUES ---

func _on_hour_changed(hour: int):
	for guest in active_guests:
		_process_guest_needs(guest)

func _process_guest_needs(guest: GuestNPC):
	if not guest.is_inside_house: return

	guest.satiety = max(0.0, guest.satiety - 5.0) 
	
	# 1. STRESS SCALES WITH SATIETY
	var stress_gain = 2.0
	if guest.satiety < 50.0:
		# Add up to 5 extra stress per hour the hungrier they get
		stress_gain += ((50.0 - guest.satiety) / 10.0) 
	
	if guest.satiety <= 20.0:
		stress_gain += 10.0 # Starving panic spike
		guest.spawn_bark("I'm so hungry...")

	guest.stress = min(100.0, guest.stress + stress_gain)

	# 2. Spawn Clues (Messes)
	var mess_chance = 0.10 
	if guest.stress >= 80.0:
		mess_chance = 0.40 
		
	if randf() < mess_chance and clue_prefabs.size() > 0:
		_spawn_clue_near_guest(guest)
		
	# 3. Change Locations
	if randf() < 0.50 and not guest.is_hidden:
		send_to_random_spot(guest)

func _spawn_clue_near_guest(guest: GuestNPC):
	var clue_scene = clue_prefabs.pick_random()
	var clue_instance = clue_scene.instantiate() as GuestClue
	
	# Add to world
	get_tree().current_scene.add_child(clue_instance)
	
	# Position at guest's feet with slight random offset
	var offset = Vector3(randf_range(-0.5, 0.5), 0.5, randf_range(-0.5, 0.5))
	clue_instance.global_position = guest.global_position + offset
	
	print("GuestManager: %s left a mess behind!" % guest.npc_data.name)

# --- OVERNIGHT DEPARTURES & BETRAYAL ---
func _on_day_changed():
	var departure_messages = []
	var guests_to_remove = []

	for guest in active_guests:
		# Check critical thresholds
		if guest.stress >= 90.0 or guest.satiety <= 10.0:
			if randf() < 0.6: # 60% chance they break and flee
			#if true: # DEBUG - ONLY FOR TESTING, uncomment above and remove this line
				guests_to_remove.append(guest)
				
				var reason = "starvation" if guest.satiety <= 10.0 else "extreme stress"
				var msg = "- " + guest.npc_data.name + " fled the house due to " + reason + "."
				
				# BETRAYAL CHECK (Req 4)
				# Safely get loyalty (defaults to 50 if the variable isn't on the resource yet)
				var loyalty = guest.npc_data.get("loyalty") if "loyalty" in guest.npc_data else 50.0
				
				if loyalty < 40.0 and randf() < 0.5: # 50% chance to snitch if disloyal
				#if true: # DEBUG - ONLY FOR TESTING, uncomment above and remove this line
					msg += "\n  [color=red]WARNING: They were angry and desperate. They may have informed the Regime.[/color]"
					GameState.regime_suspicion += 50.0
					GameState.set_flag("betrayed_by_guest", true)
					
				departure_messages.append(msg)

	# Process removals
	for guest in guests_to_remove:
		active_guests.erase(guest)
		guest_removed.emit(guest.npc_data) # NEW: Tell the UI they left!
		guest.queue_free() # Despawn them entirely
		
	# Trigger the morning report UI if anyone left
	if departure_messages.size() > 0:
		GameState.set_flag("has_morning_report", true)
		var full_text = "\n\n".join(departure_messages)
		EventBus.show_morning_report.emit("OVERNIGHT EVENTS", full_text)

func _trigger_raid_panic():
	for guest in active_guests:
		# If they aren't hidden, and they aren't currently running to a hiding spot...
		if not guest.is_hidden and guest.target_hiding_spot == null:
			print("GuestManager: %s is panicking!" % guest.npc_data.name)
			guest.spawn_bark("Oh no, they're here! Hide me!")
			
			# Send them to a random idle spot (which acts as a corner)
			send_to_random_spot(guest)
			
			# TODO: Once animations are in, play the cower animation here!
			# guest.anim.play("cower")
