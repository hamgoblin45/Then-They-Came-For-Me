extends Node

signal search_step_started(inv: InventoryData, index: int, duration: float)
signal search_finished(caught: bool, item: ItemData, qty: int, index: int)
signal search_busted_visuals(index: int) # NEW: Tells UI to do the jumpscare
signal house_raid_status(message: String) 
signal raid_finished

var current_search_inventory: InventoryData = null
var current_search_index: int = -1 
var search_tension: float = 0.0 
var patience: float = 15.0 
var base_patience: float = 15.0
var thoroughness: float = 0.5 
var base_thoroughness: float = 0.5
var is_searching: bool = false
var is_silent_search: bool = false 

var temp_elapse_time: float = 0.0 
var active_clues: Array[GuestClue] = []
var assigned_searcher: NPC = null



func _ready() -> void:
	EventBus.day_changed.connect(_on_day_changed)

func emit_test_values():
	EventBus.show_test_value.emit("search_tension", search_tension)
	EventBus.show_test_value.emit("patience", patience)
	EventBus.show_test_value.emit("thoroughness", thoroughness)

func start_frisk(inventory: InventoryData):
	print("SearchManager: STARTING SEARCH!")
	var old_patience = patience
	patience = base_patience
	
	is_searching = true
	if not GameState.raid_in_progress:
		search_tension = 0.0
	
	if inventory.slots.is_empty():
		search_step_started.emit(inventory, 0, 2.0)
		await get_tree().create_timer(2.0).timeout
	else:
		var elapsed_time = 0.0
		temp_elapse_time = elapsed_time
		current_search_inventory = inventory
		
		for i in range(inventory.slots.size()):
			if not is_searching or elapsed_time >= patience:
				break
			
			current_search_index = i
			var slot = inventory.slots[i]
			
			var base_time = 0.8 
			var search_duration = base_time
			
			if slot and slot.item_data:
				search_duration += (slot.item_data.concealability * 0.8)
			
			search_step_started.emit(inventory, i, search_duration)
			emit_test_values()
			
			# NEW: Play a fabric rustling sound! 
			# Randomizing the pitch slightly makes it sound like different pockets
			AudioManager.play_2d("pocket_rustle", -12.0, randf_range(0.9, 1.1))
			
			await get_tree().create_timer(search_duration).timeout
			elapsed_time += search_duration
			
			if slot and slot.item_data:
				if _discovered_contraband(slot.item_data):
					# Wait for the entire interrogation to finish
					var survived = await player_busted(slot.item_data, slot.quantity, i)
					patience = old_patience
					
					if survived:
						_finish_search(false, slot.item_data, slot.quantity, i)
					else:
						_finish_search(true, slot.item_data, slot.quantity, i)
					return # End the pocket frisk early either way
	
	patience = old_patience
	_finish_search(false, null, 0, -1)

func start_external_search(inventory: InventoryData, thoroughness_modifier: float = 0.5):
	is_searching = true
	is_silent_search = true
	thoroughness = thoroughness_modifier
	
	for i in range(inventory.slots.size()):
		if not is_searching: break
		
		var slot = inventory.slots[i]
		var search_duration = 1.0
		if slot and slot.item_data:
			search_duration += (slot.item_data.concealability * 0.5)
			
		emit_test_values()
		search_step_started.emit(inventory, i, search_duration)
		await get_tree().create_timer(search_duration).timeout
		
		if slot and slot.item_data:
			if _discovered_contraband(slot.item_data):
				var survived = await player_busted_external(inventory, slot, i)
				is_silent_search = false
				if survived:
					_finish_search(false, slot.item_data, slot.quantity, i)
				else:
					is_searching = false
					_finish_search(true, slot.item_data, slot.quantity, i)
				return
				
	is_silent_search = false

func start_house_raid():
	is_searching = true
	var hiding_spots: Array = get_tree().get_nodes_in_group("hiding_spots")
	var containers: Array = get_tree().get_nodes_in_group("house_containers")
	active_clues.assign(get_tree().get_nodes_in_group("guest_clues"))
	
	print("SearchManager: HOUSE RAID COMMENCING")
	
	var total_targets = hiding_spots.size() + containers.size()
	var search_count = clamp(5 + int(GameState.regime_suspicion / 10.0), 5, total_targets)
	
	var potential_targets = []
	potential_targets.append_array(hiding_spots)
	potential_targets.append_array(containers)
	
	potential_targets.sort_custom(func(a,b):
		var a_score = a.concealment_score if a is HidingSpot else 0.1
		var b_score = b.concealment_score if b is HidingSpot else 0.1
		return (a_score + randf_range(-0.3, 0.3)) < (b_score + randf_range(-0.3, 0.3))
	)
	
	for i in range(search_count):
		if not is_searching: break
		
		var target = potential_targets.pop_front()
		if not target: break
		
		if assigned_searcher:
			var move_pos = target.global_position
			
			# 1. Try to find our new specific standing marker!
			if target.has_node("StandPos"):
				move_pos = target.get_node("StandPos").global_position
			elif target.get_parent() and target.get_parent().has_node("StandPos"):
				move_pos = target.get_parent().get_node("StandPos").global_position
			else:
				# 2. Fallback: Step exactly 1.5 meters out from the FRONT of the object
				move_pos = target.global_position + (target.global_transform.basis.z * 1.5)
				
			assigned_searcher.command_move_to(move_pos)
			await assigned_searcher.destination_reached
			assigned_searcher.look_at_target(target)
		
		if target is HidingSpot:
			await _search_hiding_spot(target)
		else:
			var container_node = target.get_parent()
			if container_node and "container_inventory" in container_node:
				await _search_container_during_raid(container_node.container_inventory, thoroughness)
	
	_finish_house_raid(hiding_spots)

func _search_container_during_raid(inventory: InventoryData, thoroughness_mod: float):
	if not inventory or inventory.slots.is_empty():
		await get_tree().create_timer(2.0).timeout
		return

	for i in range(inventory.slots.size()):
		if not is_searching: break
		
		var slot = inventory.slots[i]
		var search_duration = 1.0
		
		if slot == null:
			search_duration = 0.5 
		elif slot.item_data:
			search_duration += (slot.item_data.concealability * 0.5)
		
		await get_tree().create_timer(search_duration).timeout
		
		if assigned_searcher and i % 3 == 0: 
			assigned_searcher.spawn_bark("...") 
		
		if slot and slot.item_data:
			if _discovered_contraband(slot.item_data):
				var survived = await player_busted_external(inventory, slot, i)
				if not survived:
					is_searching = false # Arrest triggers, stop the house raid loop
				return # End this specific container search regardless
	
	if assigned_searcher: assigned_searcher.spawn_bark("Hmm, nothing here")

func _finish_house_raid(hiding_spots: Array):
	raid_finished.emit()
	assigned_searcher = null
	thoroughness = base_thoroughness
	patience = base_patience
	search_tension = 0.0
	GameState.raid_in_progress = false
	GameState.regime_suspicion -= 5.0
	EventBus.stat_changed.emit("suspicion")
	
	for spot in hiding_spots:
		if spot is HidingSpot and spot.occupant:
			await get_tree().create_timer(2.5).timeout
			spot._extract_occupant()

func _search_hiding_spot(spot: HidingSpot):
	var dur = 3.0 + (spot.concealment_score * 5.0)
	
	# NEW: Chance to make noise during the search!
	if spot.occupant and spot.occupant is GuestNPC:
		var guest = spot.occupant
		var noise_chance = 0.0
		if guest.stress > 50.0: noise_chance += (guest.stress - 50.0) / 100.0 # Up to 50% chance
		if guest.satiety < 50.0: noise_chance += (50.0 - guest.satiety) / 100.0 # Up to 50% chance
		
		if randf() < noise_chance:
			house_raid_status.emit("A noise came from the " + spot.name + "!")
			dur *= 0.5 # The search speeds up because the officer heard them!

	await get_tree().create_timer(dur).timeout
	
	if spot.occupant:
		var discovery_chance = (thoroughness + (GameState.regime_suspicion / 100.0)) / (spot.concealment_score + 0.1)
		
		# NEW: Stat Penalty to concealment
		if spot.occupant is GuestNPC:
			var guest = spot.occupant
			if guest.stress > 50.0: discovery_chance += (guest.stress - 50.0) / 100.0
			if guest.satiety < 50.0: discovery_chance += (50.0 - guest.satiety) / 100.0

		if randf() < discovery_chance:
			_guest_captured(spot.occupant)
			is_searching = false

func guest_spotted_in_open(searcher_npc: NPC, guest_npc: NPC):
	if not is_searching: return
	is_searching = false 
	searcher_npc.command_move_to(GameState.player.global_position)
	_guest_captured(guest_npc)

func _guest_captured(npc: NPC):
	is_searching = false
	var flag_name = npc.npc_data.id + "_captured"
	GameState.world_flags[flag_name] = true
	GameState.world_flags["raid_failed_guest_found"] = true
	
	if assigned_searcher:
		assigned_searcher.command_stop()
		assigned_searcher.spawn_bark("Hey! Who's this!")
		await get_tree().create_timer(1.0).timeout
		assigned_searcher.look_at_target(npc)
		
		# FIX: Look at the Grunt who just yelled!
		GameState.talking_to = assigned_searcher 
	
	DialogueManager.start_dialogue("raid_guest_discovered", assigned_searcher, "Officer")

func _discovered_contraband(item: ItemData) -> bool:
	if item.contraband_level <= GameState.legal_threshold:
		return false
	var discovery_chance = (thoroughness) / (item.concealability + 0.1)
	return randf() < discovery_chance

func clue_discovered(clue: GuestClue):
	patience += 15.0
	thoroughness = min(thoroughness + 0.15, 1.0)
	search_tension += 10.0

func _finish_search(caught: bool, item: ItemData, qty: int, index: int):
	is_searching = false
	current_search_inventory = null
	current_search_index = -1
	search_finished.emit(caught, item, qty, index)
	AudioManager.stop_audio("pocket_rustle")

func player_busted(item: ItemData, qty: int, index: int) -> bool:
	var penalty = (item.contraband_level * qty) * 2.5 
	GameState.regime_suspicion += penalty
	EventBus.stat_changed.emit("suspicion")
	GameState.world_flags["busted_with_contraband"] = true
	EventBus.world_changed.emit("busted_with_contraband", true)
	
	if current_search_inventory:
		current_search_inventory.slots[index] = null
		EventBus.inventory_item_updated.emit(current_search_inventory, index)
	
	# NEW: Stop the rustling immediately!
	AudioManager.stop_audio("pocket_rustle")
	
	search_busted_visuals.emit(index)
	AudioManager.play_2d("busted_sting", 0.0)
	
	await get_tree().create_timer(1.5).timeout
	return await interrogation_started(item)

func player_busted_external(inventory: InventoryData, slot: SlotData, index: int) -> bool:
	var penalty = (slot.item_data.contraband_level * slot.quantity) * 2.5
	GameState.regime_suspicion += penalty
	EventBus.stat_changed.emit("suspicion")
	
	inventory.slots[index] = null
	EventBus.inventory_item_updated.emit(inventory, index)
	AudioManager.play_2d("busted_jumpscare", 0.0)
	
	await get_tree().create_timer(1.5).timeout
	return await interrogation_started(slot.item_data)

func contraband_spotted_in_open(officer: NPC, item_node: Node3D, item_data: ItemData, qty: int):
	if not is_searching and not GameState.raid_in_progress: 
		return 
	
	is_searching = false 
	officer.command_stop()
	officer.look_at_target(item_node)
	officer.spawn_bark("What is this doing here?!")
	
	if is_instance_valid(item_node):
		item_node.queue_free()
	
	var penalty = (item_data.contraband_level * qty) * 2.5
	GameState.regime_suspicion += penalty
	EventBus.stat_changed.emit("suspicion")
	GameState.world_flags["busted_with_contraband"] = true
	EventBus.world_changed.emit("busted_with_contraband", true)
	
	await get_tree().create_timer(1.5).timeout
	var survived = await interrogation_started(item_data)
	if not survived:
		search_finished.emit(true, item_data, qty, -1)

# --- INTERROGATION LOGIC ---

func interrogation_started(item: ItemData) -> bool:
	var dialogue_key = "default_contraband_questioning"
	if item.interrogation_dialogue_id != "":
		dialogue_key = item.interrogation_dialogue_id + "_questioning"
	
	# Cinematic camera focus on whoever found it!
	if assigned_searcher:
		GameState.talking_to = assigned_searcher
	else:
		# If assigned_searcher is null, we are at the front door frisk.
		# (Assuming your Major is in a "major" group, or just use the current talking_to)
		pass 
	
	# NEW: Inject the item details into Dialogic!
	Dialogic.VAR.contraband_name = item.name
	Dialogic.VAR.contraband_level = str(item.contraband_level)
	
	# Start the dialogue
	DialogueManager.start_dialogue(dialogue_key, assigned_searcher, "Officer")
	
	var choice = await DialogueManager.dialogue_choice_selected
	
	# Wait for the questioning dialogue to close
	await DialogueManager.dialogue_ended
	
	# Branch based on their choice
	if choice == "lie":
		return await _handle_lie_attempt(item)
	else:
		return await _handle_fess_up(item)

func _handle_lie_attempt(item: ItemData) -> bool:
	var chance = (item.concealability * 0.5) / (1.0 + (GameState.regime_suspicion / 100.0))
	
	if randf() < chance:
		print("SearchManager: They bought your lie")
		GameState.regime_suspicion += 2.0 
		DialogueManager.start_dialogue("contraband_lie_success", assigned_searcher, "Officer")
		await DialogueManager.dialogue_ended
		return true # Survived!
	else:
		print("SearchManager: They didn't buy your lie")
		DialogueManager.start_dialogue("contraband_lie_fail", assigned_searcher, "Officer")
		await DialogueManager.dialogue_ended
		return await _apply_penalty(item, true)

func _handle_fess_up(item: ItemData) -> bool:
	DialogueManager.start_dialogue("contraband_fess_up", assigned_searcher, "Officer")
	await DialogueManager.dialogue_ended
	return await _apply_penalty(item, false)

func _apply_penalty(item: ItemData, was_caught_lying: bool) -> bool:
	var multiplier: float = 2.0 if was_caught_lying else 1.0
	var level = item.contraband_level
	
	var fine_amount: int = 0
	var consequence_type: String = "fine" # default to fine
	
	# 1. Determine Consequence based on Level
	match level:
		1:
			fine_amount = int(50 * multiplier)
			GameState.regime_suspicion += 5.0 * multiplier
		2:
			fine_amount = int(150 * multiplier)
			GameState.regime_suspicion += 10.0 * multiplier
			if was_caught_lying: 
				consequence_type = "arrest" # Escalate if they lied
		3:
			GameState.regime_suspicion += 20.0 * multiplier
			consequence_type = "arrest"
		4:
			GameState.regime_suspicion += 40.0 * multiplier
			consequence_type = "game_over"

	# 2. Apply Custom Item Overrides (If you set them in the Resource)
	if item.contraband_consequences.has("type"):
		consequence_type = item.contraband_consequences["type"]
	if item.contraband_consequences.has("fine"):
		fine_amount = int(item.contraband_consequences["fine"] * multiplier)

	# 3. Inject variables into Dialogic
	Dialogic.VAR.current_fine = fine_amount
	Dialogic.VAR.player_money = GameState.money

	# 4. Route to the correct Sequence
	match consequence_type:
		"fine":
			DialogueManager.start_dialogue("fine_demand", assigned_searcher, "Officer")
			
			var choice = await DialogueManager.dialogue_choice_selected
			await DialogueManager.dialogue_ended
			
			if choice == "pay_fine":
				print("SearchManager: Fine paid.")
				GameState.money -= fine_amount
				EventBus.money_updated.emit(GameState.money)
				return true 
			else:
				print("SearchManager: Fine refused! Arresting.")
				var reason = "Refusal / Inability to pay fines for " + item.name
				var details = "PENALTY: 1 Day Incarceration\n(Health & Energy Halved)"
				EventBus.player_arrested.emit(reason, details)
				return false 
				
		"arrest":
			DialogueManager.start_dialogue("arrest_consequence", assigned_searcher, "Officer")
			await DialogueManager.dialogue_ended
			var reason = "Possession of Class " + str(level) + " Contraband (" + item.name + ")"
			var details = "PENALTY: 1 Day Incarceration\n(Health & Energy Halved)"
			EventBus.player_arrested.emit(reason, details)
			AudioManager.play_2d("handcuffs", -4.5, 1.0)
			return false
			
		"game_over":
			DialogueManager.start_dialogue("game_over_consequence", assigned_searcher, "Officer")
			await DialogueManager.dialogue_ended
			var reason = "Possession of Class " + str(level) + " Contraband (" + item.name + ")"
			EventBus.game_over.emit(reason)
			return false
			
	return false

func _on_day_changed():
	is_searching = false
	is_silent_search = false
	assigned_searcher = null
	current_search_inventory = null
	current_search_index = -1
	search_tension = 0.0
	patience = base_patience
	thoroughness = base_thoroughness
