extends Node

# References to Actors (ADD HERE WHEN CREATING NEW CHARACTERS THAT CAN VISIT)
@export var officer_major_npc: NPC
@export var officer_grunt_1: NPC # Searcher
@export var officer_grunt_2: NPC # Back door guard
@export var fugitive_npc: NPC
@export var merchant_npc: NPC

# Locations
@export var spawn_marker: Node3D
@export var door_marker: Node3D
@export var back_door_marker: Node3D
@export var side_yard_marker: Node3D # NEW: The corner they must walk around
@export var leave_marker: Node3D

var current_visitor: NPC = null
var raid_party_arrived_count: int = 0

var daily_schedule: Dictionary = {}

func _ready() -> void:
	EventBus.visitor_arrived.connect(_on_visitor_arrived)
	EventBus.door_opened_for_visitor.connect(_on_door_opened)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	EventBus.visitor_leave_requested.connect(_send_npc_away)
	EventBus.day_changed.connect(_on_day_changed)
	EventBus.hour_changed.connect(_on_hour_changed)
	
	# Wait one frame to ensure the level and all characters are fully loaded
	await get_tree().process_frame 
	
	# Check for Debug Flags from the Testing Hub
	if GameState.get_flag("debug_start_with_fugitive"):
		print("DEBUG: Force spawning fugitive as guest!")
		if fugitive_npc:
			# NEW: Find the indoor spots and teleport them directly there
			var spots = get_tree().get_nodes_in_group("guest_idle_spots")
			if spots.size() > 0:
				var random_spot = spots.pick_random()
				fugitive_npc.global_position = random_spot.global_position
				# Optional: Make them match the spot's rotation so they aren't facing a wall
				fugitive_npc.rotation = random_spot.rotation 
			
			fugitive_npc.show()
			_convert_to_guest(fugitive_npc)

	# Generate the schedule for Day 1 immediately upon loading the level!
	_generate_daily_schedule()

# --- VISITOR SCHEDULING SYSTEM ---

func _on_day_changed():
	current_visitor = null
	raid_party_arrived_count = 0
	daily_schedule.clear()
	
	# Wait exactly one frame so GuestManager can finish setting flags
	await get_tree().process_frame 
	
	_generate_daily_schedule()

# Adding New Visitors Later
# Whenever you create a new NPC (like a nosy neighbor or a black-market smuggler), you just add a new if block into Step 3 to append them to the event_pool,
# give them a baseline weight, and give them valid hours. The system will automatically handle the rest!
func _generate_daily_schedule():
	# 1. MANDATORY EVENTS (Overrides normal schedules)
	if GameState.get_flag("betrayed_by_guest"):
		GameState.set_flag("betrayed_by_guest", false) 
		GameState.set_flag("raid_reason_betrayal", true) 
		
		daily_schedule[9] = "betrayal_raid"
		print("VisitorManager: Betrayal Raid scheduled for 9:00 AM!")
		return # Skip all normal visitors today!
	
	# 1.5. GUARANTEED STORY EVENTS (Does not skip normal visitors)
	# Case Example 1: The Rebel Recruiter
	# We check if the attack happened, AND we check a secondary flag to ensure 
	# he only visits once and doesn't show up every single day forever!
	if GameState.get_flag("first_rebel_attack") and not GameState.get_flag("rebel_recruiter_visited"):
		GameState.set_flag("rebel_recruiter_visited", true) # Lock it out for future days
		
		# Assign him to a specific hour (e.g., 18:00 / 6 PM)
		daily_schedule[18] = "rebel_recruiter"
		print("VisitorManager: Story Event - Recruiter scheduled for 18:00")

	# Case Example 2: The Neighbor Kid
	if GameState.get_flag("neighbor_arrested") and not GameState.get_flag("neighbor_kid_visited"):
		GameState.set_flag("neighbor_kid_visited", true)
		
		# Or assign them to a random hour so it's a surprise!
		var kid_hours = [8, 9, 10, 11]
		daily_schedule[kid_hours.pick_random()] = "neighbor_kid"
		print("VisitorManager: Story Event - Kid scheduled for morning.")

	# 2. DETERMINE RNG VISITOR COUNT
	var num_visitors_today = randi_range(1, 3) # 1 to 3 visitors max per day
	var event_pool = []

	# 3. BUILD TODAY'S EVENT POOL
	# (Only add events to the pool if their conditions are met)

	# A. The Merchant (Always available)
	event_pool.append({
		"type": "merchant",
		"weight": 10.0, 
		"hours": [9, 10, 11, 13, 14, 15, 16] # Standard business hours
	})

	# B. The Fugitive (Available if you have room / randomness)
	# Example condition: Only if you don't already have 3 guests
	if GuestManager.active_guests.size() < 3:
		event_pool.append({
			"type": "fugitive",
			"weight": 6.0,
			"hours": [20, 21, 22, 23, 0, 1] # Late at night
		})

	# C. Random Police Raid (Scales with Suspicion!)
	if GameState.regime_suspicion > 30.0:
		event_pool.append({
			"type": "random_raid",
			# The higher the suspicion, the more heavily weighted this becomes
			"weight": GameState.regime_suspicion / 4.0, 
			"hours": [8, 11, 14, 17, 19] 
		})

	# 4. ROLL FOR VISITORS
	for i in range(num_visitors_today):
		if event_pool.is_empty(): break
		
		# Calculate total weight of the pool
		var total_weight = 0.0
		for event in event_pool:
			total_weight += event["weight"]
			
		# Pick a random number up to the total weight
		var roll = randf_range(0.0, total_weight)
		var selected_event = null
		
		# Find which event we landed on
		var current_weight = 0.0
		for event in event_pool:
			current_weight += event["weight"]
			if roll <= current_weight:
				selected_event = event
				break
				
		# 5. ASSIGN AN HOUR
		if selected_event:
			# Shuffle the valid hours so they don't always come at the exact same time
			var available_hours = selected_event["hours"].duplicate()
			available_hours.shuffle()
			
			for h in available_hours:
				# Make sure no one is already scheduled for this exact hour
				if not daily_schedule.has(h):
					daily_schedule[h] = selected_event["type"]
					print("VisitorManager: Scheduled ", selected_event["type"], " at ", h, ":00")
					break # Successfully scheduled!
					
			# Remove this event from the pool so we don't get 3 merchants in one day
			event_pool.erase(selected_event)

func _on_hour_changed(hour: int):
	if daily_schedule.has(hour):
		_trigger_scheduled_event(daily_schedule[hour])

func _trigger_scheduled_event(event_type: String):
	print("VisitorManager: Triggering event - ", event_type)
	
	match event_type:
		"betrayal_raid", "random_raid":
			start_raid_arrival()
		"merchant":
			start_visit(merchant_npc)
		"fugitive":
			start_visit(fugitive_npc)
		#"rebel_recruiter":
			#start_visit(rebel_recruiter_npc) # NEW
		#"neighbor_kid":
			#start_visit(neighbor_kid_npc)    # NEW

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_visit_officer"): 
		start_raid_arrival() # Updated to call the squad logic
	elif event.is_action_pressed("debug_visit_fugitive"): 
		start_visit(fugitive_npc)
	elif event.is_action_pressed("debug_visit_merchant"): 
		start_visit(merchant_npc)

# --- SOLO VISITOR LOGIC ---

func start_visit(npc: NPC) -> void:
	if current_visitor != null: return
	if not spawn_marker or not door_marker: return

	print("VisitorManager: Starting visit for %s" % npc.npc_data.name)
	current_visitor = npc
	
	npc.global_position = spawn_marker.global_position
	npc.show()
	npc.process_mode = Node.PROCESS_MODE_INHERIT
	var points: Array[Vector3] = []
	points.append(door_marker.global_position)
	
	var path = _create_visit_path(spawn_marker.global_position, points)
	npc.set_override_path(path)

# --- RAID PARTY LOGIC ---

func start_raid_arrival() -> void:
	if current_visitor != null: return
	print("VisitorManager: DISPATCHING RAID SQUAD")
	
	raid_party_arrived_count = 0
	current_visitor = officer_major_npc
	
	# 1. Spawn Everyone
	var squad = [officer_major_npc, officer_grunt_1, officer_grunt_2]
	var offset = Vector3(0,0,0)
	
	for member in squad:
		if member:
			member.global_position = spawn_marker.global_position + offset
			member.show()
			member.process_mode = Node.PROCESS_MODE_INHERIT
			offset += Vector3(0.5, 0, 0.5)

	# 2. Assign Paths
	# Major -> Front Door
	var major_path = _create_visit_path(officer_major_npc.global_position, [door_marker.global_position])
	officer_major_npc.set_override_path(major_path)
	
	# Grunt 1 -> Front Door Side
	var grunt1_pos = door_marker.global_position + (door_marker.basis.x * 1.5) + (door_marker.basis.z * 1.0)
	var grunt1_path = _create_visit_path(officer_grunt_1.global_position, [grunt1_pos])
	officer_grunt_1.set_override_path(grunt1_path)
	
	# Grunt 2 -> Side Yard -> Back Door
	if back_door_marker:
		var points: Array[Vector3] = []
		
		# If we defined a corner waypoint, go there first
		if side_yard_marker:
			points.append(side_yard_marker.global_position)
			
		points.append(back_door_marker.global_position)
		
		var grunt2_path = _create_visit_path(officer_grunt_2.global_position, points)
		officer_grunt_2.set_override_path(grunt2_path)

# --- UTILS ---

func _create_visit_path(start: Vector3, target_points: Array[Vector3]) -> PathData:
	var new_path = PathData.new()
	new_path.start_pos = start
	new_path.points = target_points # Assign the list of points
	new_path.wait_for_player = true 
	new_path.anim_on_arrival = "Idle"
	return new_path

# --- ARRIVAL HANDLING ---

func _on_visitor_arrived(npc: NPC) -> void:
	# If it's a Raid Member
	if npc == officer_major_npc or npc == officer_grunt_1:
		raid_party_arrived_count += 1
		npc.look_at_target(door_marker) # Face door
		
		# Wait for both front-door officers to arrive
		if raid_party_arrived_count >= 2:
			print("VisitorManager: Raid Party in position. Starting Sequence.")
			EventBus.raid_starting.emit()
			# We don't despawn them or send them away yet, RaidSequence takes control now
	
	elif npc == officer_grunt_2:
		print("VisitorManager: Backup positioned at back door.")
		npc.look_at_target(back_door_marker) # Face back door

	elif npc == current_visitor:
		# Normal Visitor
		print("VisitorManager: %s has arrived." % npc.npc_data.name)
		npc.spawn_bark("Knock knock!")
		npc.look_at_target(GameState.player)
		npc.interactable = true 

func get_visitor_description() -> String:
	if not current_visitor or not is_instance_valid(current_visitor): 
		return "Nobody is there."
		
	match current_visitor:
		officer_major_npc: return "A high-ranking Regime Officer. Armed."
		officer_grunt_1: return "A Regime Officer."
		fugitive_npc: return "A shivering figure in rags."
		merchant_npc: return "A person with a large, heavy pack."
		_: return "An unrecognizable silhouette."

func _on_door_opened() -> void:
	if current_visitor and is_instance_valid(current_visitor):
		GameState.talking_to = current_visitor
		# Determine which timeline to play
		var timeline = "default_visitor"
		
		if current_visitor == fugitive_npc:
			timeline = "fugitive_at_door"
		elif current_visitor == merchant_npc:
			timeline = "merchant_at_door"
			
		print("VisitorManager: Door opened, starting dialogue: ", timeline)
		DialogueManager.start_dialogue(timeline, current_visitor, current_visitor.npc_data.name)

func _on_dialogue_ended() -> void:
	if GameState.shopping:
		print("VisitorManager: Dialogue ended, but shopping active. Keeping visitor.")
		return

	if current_visitor and not GameState.raid_in_progress:
		_handle_post_visit_logic(current_visitor)

func _handle_post_visit_logic(npc: NPC) -> void:
	if npc == fugitive_npc:
		# FIX: Changed the default fallback from 'true' to 'false'
		if GameState.get_flag("accepted_fugitive"):
			_convert_to_guest(npc)
			current_visitor = null
			return

	print("VisitorManager: Visit complete. NPC leaving.")
	_send_npc_away()

func _send_npc_away() -> void:
	if not current_visitor or not is_instance_valid(current_visitor):
		return
	var npc = current_visitor
	var points: Array[Vector3] = []
	points.append(leave_marker.global_position)
	var path = _create_visit_path(npc.global_position, points)
	npc.set_override_path(path)
	await get_tree().create_timer(10.0).timeout
	npc.release_from_override() 
	current_visitor = null

func _convert_to_guest(npc: NPC) -> void:
	print("VisitorManager: Convert to guest run")
	# Release them from their door-waiting override path
	npc.release_from_override()
	GuestManager.make_guest(npc)
