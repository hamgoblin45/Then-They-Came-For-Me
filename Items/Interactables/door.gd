extends Node3D

@onready var anim: AnimationPlayer = $door/AnimationPlayer
@onready var interactable: Interactable = $door/Cube/Interactable
@onready var collision_shape: CollisionShape3D = $door/Cube/StaticBody3D/CollisionShape3D
@onready var npc_detect: Area3D = $NPCDetect

var open: bool = false

# --- TENSION SYSTEM ---
var is_knocking: bool = false
var visitor_patience: float = 0.0

func _ready() -> void:
	interactable.interacted.connect(_interact)
	
	# Update the interact text to hint at peeking
	#if interactable.id == "front_door":
		#interactable.interact_text = "L-Click: Open | Hold R-Click: Peek"
		
	EventBus.visitor_arrived.connect(_on_visitor_arrived)
	EventBus.day_changed.connect(_on_day_changed)

func _interact(interact_type: String, engaged: bool):
	if interact_type == "interact" or interact_type == "click":
		if not engaged: return
		toggle_door(!open)
		
		# If the door is being opened and it's the front door
		if open and interactable.id == "front_door":
			is_knocking = false # They opened it, stop the tension timer
			EventBus.toggle_peephole.emit(false, "") # Force UI closed
			
			if GameState.raid_in_progress:
				EventBus.answering_door.emit()
			else:
				EventBus.door_opened_for_visitor.emit()
				
	# NEW: Peeking Logic
	elif interact_type == "r_click" and interactable.id == "front_door":
		if not open: # Can only peek if the door is closed!
			if engaged:
				# Find the VisitorManager via its group!
				var vm = get_tree().get_first_node_in_group("visitor_manager")
				var desc = "Nobody is there."
				
				if vm:
					desc = vm.get_visitor_description()
					
				EventBus.toggle_peephole.emit(true, desc)
			else:
				EventBus.toggle_peephole.emit(false, "")

func _on_visitor_arrived(npc: NPC):
	if interactable.id == "front_door" and not open:
		is_knocking = true
		visitor_patience = 45.0 
		print("DOOR: Someone is at the door...")
		
		# SAFELY fetch the VisitorManager via its group
		var vm = get_tree().get_first_node_in_group("visitor_manager")
		var pitch = 1.0
		
		# Make the knock deeper and heavier if it's the Police Major
		if vm and vm.current_visitor == vm.officer_major_npc:
			pitch = 0.8
			
		AudioManager.play_3d("door_knock", global_position, 0.0, pitch)

func _visitor_lost_patience():
	print("DOOR: Visitor lost patience and left.")
	is_knocking = false
	EventBus.toggle_peephole.emit(false, "")
	EventBus.visitor_leave_requested.emit()
	
	# SAFELY fetch the VisitorManager
	var vm = get_tree().get_first_node_in_group("visitor_manager")
	
	# If the cops hear you but aren't actively raiding, they get VERY suspicious
	if vm and vm.current_visitor == vm.officer_major_npc:
		GameState.regime_suspicion += 15.0
		EventBus.stat_changed.emit("suspicion")

func _process(delta: float) -> void:
	# Only manage patience for normal visitors (RaidSequence handles its own breach timer!)
	if is_knocking and not open and not GameState.raid_in_progress:
		visitor_patience -= delta
		
		# NOISE CHECK: Is the player moving fast?
		if GameState.player and GameState.player.velocity.length() > 3.0:
			# Patience drains 3x faster if you are stomping around!
			visitor_patience -= delta * 2.0 
			
			# Slowly raise suspicion because they can hear you ignoring them
			GameState.regime_suspicion += 0.1 * delta 
			EventBus.stat_changed.emit("suspicion")
			
		if visitor_patience <= 0.0:
			_visitor_lost_patience()


func toggle_door(state: bool):
	open = state
	
	if open:
		anim.play("Open")
		AudioManager.play_3d("door_open", global_position, -5.0, 1.0)
		if interactable.id == "front_door":
			interactable.interact_text = "Close"
		else:
			interactable.interact_text = "Close"
			
		collision_shape.set_deferred("disabled", true)
		EventBus.toggle_peephole.emit(false, "") # Force peephole closed if open
	else:
		anim.play("Close")
		
		interactable.interact_text = "Open"
		#if interactable.id == "front_door":
			#interactable.interact_text = "L-Click: Open | Hold R-Click: Peek"
			
		await anim.animation_finished
		AudioManager.play_3d("door_close", global_position, -5.0, 1.0)
		collision_shape.disabled = false

func _on_npc_detect_body_entered(body: Node3D) -> void:
	if body is NPC:
		if not open and interactable.id != "front_door":
			toggle_door(true) # force open for npc

func _on_day_changed():
	is_knocking = false
	if open:
		toggle_door(false) # Make sure the door is closed every morning!
