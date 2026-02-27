extends NPC
class_name OfficerNPC

enum {INVESTIGATING}

func _physics_process(delta: float) -> void:
	super._physics_process(delta) 
	
	# NEW: Cops are hyper-vigilant during a raid!
	if GameState.raid_in_progress:
		vision_range = 10.0 # See further
		vision_angle = 85.0 # Almost 180 degree peripheral vision!
	else:
		vision_range = 8.0
		vision_angle = 60.0
		
	if state == INVESTIGATING:
		_handle_investigation(delta)
		move_and_slide()
		return
	
	if GameState.raid_in_progress and state != INVESTIGATING:
		_scan_for_targets()
	#
	#if dynamic_target_pos:
		#print("Distance to dynamic target pos: %s" % global_position.distance_to(dynamic_target_pos))

func _scan_for_targets():
	# 1. Prioritize Guests (Immediate Arrest)
	var guests = get_tree().get_nodes_in_group("guests")
	for guest in guests:
		if guest.get("is_hidden"): continue
		
		if _can_see_target(guest):
			_arrest_guest(guest)
			return # Stop scanning if we found a person
	
	# 2. Dropped Contraband (NEW)
	var dropped_items = get_tree().get_nodes_in_group("grabbables")
	for item in dropped_items:
		# Check visibility
		if _can_see_target(item):
			# Check if it has data and is illegal
			if item.get("slot_data") and item.slot_data.item_data:
				var data = item.slot_data.item_data
				if data.contraband_level > GameState.legal_threshold:
					_found_dropped_contraband(item, data, item.slot_data.quantity)
					return
	
	# 2. Check Clues (Bark & Flag, but keep moving)
	var clues = get_tree().get_nodes_in_group("clues")
	for clue in clues:
		if clue.get("is_discovered"): continue
		
		if _can_see_target(clue):
			_spot_clue_mid_stride(clue)
			return

func _spot_clue_mid_stride(clue: Node):
	# Don't stop moving, just acknowledge it
	clue.is_discovered = true
	EventBus.clue_found.emit(clue) 
	spawn_bark("What's this mess?")
	# SearchManager/RaidSequence listens to 'clue_found' to raise suspicion

func _arrest_guest(guest: NPC):
	command_stop() # Full stop
	look_at_target(guest)
	spawn_bark("FREEZE!")
	state = INVESTIGATING
	SearchManager.guest_spotted_in_open(self, guest)

func _found_dropped_contraband(item_node: Node3D, data: ItemData, qty: int):
	state = INVESTIGATING
	SearchManager.contraband_spotted_in_open(self, item_node, data, qty)

func _handle_investigation(_delta):
	pass
