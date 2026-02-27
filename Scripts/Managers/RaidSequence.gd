extends Node
class_name RaidSequence

@export_group("Actors")
@export var major_npc: NPC
@export var search_grunt_npc: OfficerNPC # The searcher
@export var backup_grunt_npc: NPC # The back door guard
@export var player: CharacterBody3D # Need ref for frisk command

@export_group("Positions")
@export var door_blocker_pos: Node3D # Front Door standing spot
@export var major_stand_aside_pos: Node3D # Where Major moves to let Grunt in
@export var back_door_pos: Node3D # Where Backup Grunt stands
@export var leave_pos: Node3D # Where they walk to when leaving
@export var front_door: Node3D 

var door_answered: bool = false
var countdown_active: bool = false

func _ready() -> void:
	EventBus.raid_starting.connect(start_raid_event)
	EventBus.answering_door.connect(answer_door)
	
	SearchManager.raid_finished.connect(_on_raid_finished)
	EventBus.day_changed.connect(_on_day_changed)

func start_raid_event() -> void:
	print("RaidSequence: RAID STARTING! 20s Countdown.")
	GameState.raid_in_progress = true
	door_answered = false
	
	# 1. Position Major and Search Grunt at Front Door
	if door_blocker_pos:
		major_npc.global_position = door_blocker_pos.global_position
		major_npc.look_at_target(front_door) 
		major_npc.rotation = door_blocker_pos.rotation
		
		# Position Search Grunt slightly behind/right
		search_grunt_npc.global_position = door_blocker_pos.global_position + (Vector3.BACK * 0.85) + (Vector3.LEFT * 0.7)
		search_grunt_npc.look_at_target(front_door)

	# 2. Position Backup Grunt at Back Door
	if backup_grunt_npc and back_door_pos:
		backup_grunt_npc.global_position = back_door_pos.global_position
		backup_grunt_npc.look_at_target(null) # Just face forward or look at a specific target
	
	# 3. Lock NPCs
	major_npc.command_stop()
	search_grunt_npc.command_stop()
	if backup_grunt_npc:
		backup_grunt_npc.command_stop()
	
	major_npc.state = major_npc.WAIT
	
	_run_countdown(20.0)

func _run_countdown(seconds: float) -> void:
	countdown_active = true
	var time_left = seconds
	
	while time_left > 0:
		if door_answered:
			countdown_active = false
			return # Exit loop if player answers door
		
		# Trigger every 5 seconds
		if int(time_left) % 5 == 0:
			major_npc.spawn_bark("OPEN THE DOOR!")
			
			# NEW: Escalating Door Audio
			var sound_to_play = "door_knock"
			var db = 3.0
			if time_left <= (seconds / 2.0):
				sound_to_play = "door_pound"
				db = 13.0
				
			# Play the sound spatially at the front door's location
			if front_door:
				AudioManager.play_3d(sound_to_play, front_door.global_position, db, 1.0)
		
		EventBus.raid_timer_updated.emit(snapped(time_left, 0.1))
		
		await get_tree().create_timer(1.0).timeout
		time_left -= 1.0
	
	if not door_answered:
		_force_entry()

func _force_entry() -> void:
	door_answered = true
	print("RaidSequence: TIMER EXPIRED. FORCING ENTRY!!!")
	
	# Penalty
	GameState.regime_suspicion += 20.0
	EventBus.stat_changed.emit("suspicion")
	
	major_npc.spawn_bark("THAT'S IT! BREAK IT DOWN!")
	await get_tree().create_timer(1.9).timeout
	
	if front_door.has_method("toggle_door"):
		front_door.toggle_door(true) # Kick open the door
	
	await get_tree().create_timer(0.9).timeout
	major_npc.spawn_bark("Get over here! Turn out your pockets!")
	_begin_frisk()

func answer_door() -> void:
	if door_answered: return 
	door_answered = true
	print("RaidSequence: Answering door")
	
	EventBus.raid_timer_updated.emit(0.0) # Clear timer
	
	# FIX: Explicitly tell the game we are looking at the Major!
	GameState.talking_to = major_npc 
	
	# DialogueManager handles mouse visibility
	DialogueManager.start_dialogue("major_search_announce_test", major_npc, major_npc.npc_data.name)
	await DialogueManager.dialogue_ended
	
	_begin_frisk()



func _begin_frisk() -> void:
	# Begin frisk
	EventBus.force_ui_open.emit(true)
	GameState.can_move = false
	
	SearchManager.house_raid_status.emit("The Major is patting you down...")
	SearchManager.start_frisk(GameState.pockets_inventory)
	
	# Wait for signal result
	var result = await SearchManager.search_finished # Returns [caught, item, qty]
	
	EventBus.force_ui_open.emit(false)
	GameState.can_move = true
	
	var caught = result[0]
	var item = result[1]
	
	if caught:
		print("RaidSequence: Player caught during frisk.")
		# SearchManager already called interrogation_started inside player_busted
	else:
		print("RaidSequence: Clean frisk. Sending in grunt.")
		_send_in_grunt()

func _send_in_grunt() -> void:
	if not GameState.raid_in_progress: return
	
	# FIX: Look back at the Major after the frisk!
	GameState.talking_to = major_npc
	
	DialogueManager.start_dialogue("major_raid_frisk_complete", major_npc, major_npc.npc_data.name)
	await DialogueManager.dialogue_ended
	
	# Major steps aside
	if major_stand_aside_pos:
		major_npc.command_move_to(major_stand_aside_pos.global_position)
		await major_npc.destination_reached
		major_npc.look_at_target(GameState.player)
	
	print("RaidSequence: Starting House Search")
	
	# Hand control to SearchManager
	SearchManager.assigned_searcher = search_grunt_npc
	SearchManager.start_house_raid()

func _on_raid_finished() -> void:
	# SearchManager emits 'raid_finished' when the grunt is done searching
	print("RaidSequence: Raid Completed. Squad departing.")
	
	var exit_loc = Vector3(0, 0, 50)
	if leave_pos:
		exit_loc = leave_pos.global_position
		
	major_npc.spawn_bark("We're done here. Let's move.")
	
	# Send everyone away
	major_npc.command_move_to(exit_loc)
	if backup_grunt_npc:
		backup_grunt_npc.command_move_to(exit_loc)
		
	# SearchManager sends the search_grunt_npc away automatically, 
	# but we can reinforce it here just in case.
	if search_grunt_npc:
		search_grunt_npc.command_move_to(exit_loc)
		
	# Despawn logic could go here after a delay

func _on_day_changed():
	door_answered = false
	countdown_active = false
	
	# Hard hide/reset officers so they aren't still standing in your house
	var squad = [major_npc, search_grunt_npc, backup_grunt_npc]
	for npc in squad:
		if npc and is_instance_valid(npc):
			npc.command_stop()
			npc.release_from_override()
			npc.hide()
			# Teleport them far away into a holding area under the map
			npc.global_position = Vector3(0, -50, 0)
