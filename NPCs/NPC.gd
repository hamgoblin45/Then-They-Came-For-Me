extends CharacterBody3D
class_name NPC

@export var npc_data: NPCData

@export_group("AI Settings")
var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")
var gravity_enabled: bool = true
var interactable: bool = true

@onready var interact_area: Interactable = $Interactable
@onready var look_at_node: Node3D = $LookAtNode
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var bark_anchor: Node3D = $BarkAnchor

@export_group("Vision Settings")
@export var vision_range: float = 4.2
@export var vision_angle: float = 60.0
@onready var vision_ray: RayCast3D = %VisionRay

# Animation
var anim: AnimationPlayer
@onready var head: Node3D = $Head
var looking_at: Node3D

# State Machine
enum {IDLE, WALK, WAIT, ANIMATING, FOLLOWING, COMMAND_MOVE}
var state = IDLE
var prev_state
const SPEED_MULTIPLIER: float = 1.35

# Pathing & Overrides
var is_under_command: bool = false 
var override_path_active: bool = false 
var dynamic_target_pos: Vector3 = Vector3.ZERO
var active_path: PathData = null # Local reference for current movement

const BARK_BUBBLE = preload("uid://cxosfcljv24w3")

signal destination_reached

func _ready() -> void:
	EventBus.minute_changed.connect(_on_time_updated)
	EventBus.world_changed.connect(_on_world_changed)
	EventBus.item_interacted.connect(_on_interact)
	EventBus.follow_player.connect(follow_player)
	
	# Setup Nav Agent
	nav_agent.path_desired_distance = 0.42
	nav_agent.target_desired_distance = 0.21
	
	if vision_ray:
		vision_ray.add_exception(self)
	
	await get_tree().process_frame 
	_check_schedule(GameState.hour, GameState.minute)

func _physics_process(delta: float) -> void:
	if GameState.paused or GameState.in_dialogue or GameState.shopping:
		# Allow gravity so they don't float if paused mid-air, but stop X/Z movement
		if not is_on_floor() and gravity_enabled:
			velocity.y -= gravity * delta
		else:
			velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0, 10.0 * delta)
			
		move_and_slide()
		return
	
	# Gravity
	if not is_on_floor() and gravity_enabled:
		velocity.y -= gravity * delta
	
	# Look At
	if is_instance_valid(looking_at):
		# Look at the chest/center of the target, not their feet!
		var target_pos = looking_at.global_position
		if looking_at is CharacterBody3D:
			target_pos.y += 1.0 
			
		look_at_node.look_at(target_pos)
		global_rotation.y = lerp_angle(global_rotation.y, look_at_node.global_rotation.y, 5.0 * delta)

	_handle_state(delta)
	move_and_slide()
	_handle_footsteps(delta)

# --- PATHING & SCHEDULES ---

func _on_time_updated(h: int, m: int):
	if not is_under_command and not override_path_active:
		_check_schedule(h, m)

func _check_schedule(h: int, m: int):
	if not npc_data or not npc_data.schedule: return
	
	var new_path = npc_data.schedule.get_path_for_time(h, m)
	# Compare against our local active_path
	if new_path and new_path != active_path:
		print("NPC %s: Schedule updated, new path found." % npc_data.name)
		active_path = new_path
		active_path.reset_path()
		set_path(active_path)

func set_path(path: PathData):
	look_at_target(null)
	active_path = path
	
	if path and path.get_next_target():
		state = WALK
		if path.start_pos != Vector3.ZERO:
			global_position = path.start_pos
	else:
		state = IDLE

# NEW: Dynamic Visit Path
func set_override_path(path: PathData):
	print("NPC %s: Starting Override Path (Visitor Mode)" % npc_data.name)
	override_path_active = true
	interactable = false 
	
	# FIX: Assign to local variable, ignoring schedule entirely
	active_path = path
	active_path.reset_path()
	
	# Manually trigger start
	state = WALK
	
func release_from_override():
	override_path_active = false
	active_path = null 
	interactable = true
	_check_schedule(GameState.hour, GameState.minute) 
	print("NPC %s released from override, resuming schedule." % npc_data.name)

func _finish_path():
	print("%s reached end of path." % npc_data.name)
	
	if active_path and active_path.anim_on_arrival != "":
		state = ANIMATING
		# anim.play(active_path.anim_on_arrival)
	else:
		state = IDLE
	
	interactable = true
	if active_path:
		npc_data.waiting_for_player = active_path.wait_for_player
	
	if override_path_active:
		print("NPC %s: Override Path Complete." % npc_data.name)
		EventBus.visitor_arrived.emit(self)
	
	EventBus.path_finished.emit(npc_data, active_path)

# --- MOVEMENT LOGIC ---

func _handle_state(delta):
	match state:
		IDLE, ANIMATING:
			velocity.x = move_toward(velocity.x, 0, 2.0 * delta)
			velocity.z = move_toward(velocity.z, 0, 2.0 * delta)
		
		WALK:
			if not get_tree().paused and not GameState.paused:
				_handle_schedule_nav(delta)
		
		COMMAND_MOVE:
			_handle_dynamic_nav(delta)

# Schedule Nav (Waypoint based)
func _handle_schedule_nav(delta: float):
	if not active_path: 
		state = IDLE
		return
		
	var current_target = active_path.get_current_target()
	if current_target == Vector3.ZERO: 
		_finish_path()
		return

	# Use NavAgent for schedule too if you want obstacle avoidance
	nav_agent.target_position = current_target
	var next_pos = nav_agent.get_next_path_position()
	var dir = global_position.direction_to(next_pos)
	
	if global_position.distance_to(current_target) < 1.0:
		if not active_path.advance_to_next():
			_finish_path()
			return
	
	_move_and_rotate(dir, 2.0, delta)

# Dynamic Nav (Direct Target based)
func _handle_dynamic_nav(delta: float):
	# 1. Update Target
	nav_agent.target_position = dynamic_target_pos
	
	# NEW: Anti-Softlock Distance Check! 
	var distance_to_target = global_position.distance_to(dynamic_target_pos)
	var is_close_enough = distance_to_target < 1.5 # 1.5 meters is arm's reach!
	
	# 2. Check Arrival
	if nav_agent.is_navigation_finished() or is_close_enough:
		state = IDLE
		velocity = Vector3.ZERO
		print("NPC %s arrived at command target. (Distance: %s)" % [npc_data.name, distance_to_target])
		destination_reached.emit()
		return
		
	# 3. Get Next Step from NavServer
	var next_path_position: Vector3 = nav_agent.get_next_path_position()
	var dir = global_position.direction_to(next_path_position)
	
	# 4. Move
	_move_and_rotate(dir, 3.0, delta)

func _move_and_rotate(dir: Vector3, speed: float, delta: float):
	var adjusted_speed = speed * SPEED_MULTIPLIER
	
	velocity.x = lerp(velocity.x, dir.x * adjusted_speed, 5.0 * delta)
	velocity.z = lerp(velocity.z, dir.z * adjusted_speed, 5.0 * delta)
	
	# NEW: Clean, math-based rotation!
	# Only rotate to face the walking direction if we aren't being forced to stare at someone
	if not is_instance_valid(looking_at) and dir.length() > 0.1:
		var target_angle = atan2(-dir.x, -dir.z)
		global_rotation.y = lerp_angle(global_rotation.y, target_angle, 8.0 * delta)
		
		# Smoothly rotate the character to face where they are walking
		global_rotation.y = lerp_angle(global_rotation.y, target_angle, 8.0 * delta)

# --- FOOTSTEP SYSTEM ---
var distance_walked: float = 0.0
var step_distance: float = 1.78 # NPCs usually take slightly shorter/slower steps than players


func _handle_footsteps(delta: float):
	# Only accumulate distance if they are moving
	if velocity.length() > 0.1 and is_on_floor():
		var horizontal_velocity = Vector2(velocity.x, velocity.z)
		distance_walked += horizontal_velocity.length() * delta
		
		if distance_walked >= step_distance:
			distance_walked = 0.0
			_play_footstep()
	else:
		distance_walked = 0.0

func _play_footstep():
	var surface = "default"
	
	# CAST A RAY THROUGH CODE (No Node Required!)
	# We shoot a line from their center to 1.5 meters straight down
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 0.63)
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		if collider.is_in_group("carpet"):
			surface = "carpet"
		elif collider.is_in_group("concrete"):
			surface = "concrete"
		elif collider.is_in_group("dirt"):
			surface = "dirt"
		elif collider.is_in_group("wood"):
			surface = "wood"
			
	var sound_name = "footstep_" + surface
	
	AudioManager.play_3d(sound_name, global_position, -6.0, randf_range(0.85, 1.15))

# --- COMMANDS ---

func command_move_to(target: Vector3):
	is_under_command = true
	dynamic_target_pos = target
	state = COMMAND_MOVE
	nav_agent.target_position = target
	
	# FIX: Stop staring at previous targets so we can face where we are walking!
	look_at_target(null)

func command_stop():
	is_under_command = false
	state = IDLE
	velocity = Vector3.ZERO

# --- VISION (RESTORED) ---

func look_at_target(target):
	looking_at = target

func _can_see_target(target_node: Node3D) -> bool:
	if not is_instance_valid(target_node): return false
	
	var my_eyes = global_position + Vector3(0, 1.6, 0)
	if head: my_eyes = head.global_position
	
	var target_chest = target_node.global_position + Vector3(0, 1.0, 0)
	
	# 1. Distance Check
	if my_eyes.distance_to(target_chest) > vision_range:
		return false
	
	# 2. Angle Check (The Mathematical Cone)
	var dir = my_eyes.direction_to(target_chest)
	
	# RESTORED: Negative signs for Godot's native -Z forward
	var fwd = -global_transform.basis.z
	if head: fwd = -head.global_transform.basis.z 
		
	var angle_dot = fwd.dot(dir)
	var angle_threshold = cos(deg_to_rad(vision_angle))
	
	if angle_dot < angle_threshold:
		return false # They are outside our peripheral vision!
	
	# 3. Raycast Check (Line of Sight)
	if not vision_ray: return false
	
	vision_ray.enabled = true
	var can_see = false
	
	# Check the chest first. If blocked, check the head!
	var points_to_check = [
		target_node.global_position + Vector3(0, 1.0, 0), # Chest
		target_node.global_position + Vector3(0, 1.6, 0)  # Head
	]
	
	for point in points_to_check:
		vision_ray.global_position = my_eyes 
		vision_ray.target_position = vision_ray.to_local(point)
		vision_ray.force_raycast_update()
		
		if vision_ray.is_colliding():
			var collider = vision_ray.get_collider()
			if collider == target_node or collider.get_parent() == target_node:
				can_see = true
				break # We saw them! No need to check other body parts.
				
	vision_ray.enabled = false
	return can_see

# --- INTERACTION & EVENTS ---

func _on_world_changed(flag_name: String, value: bool):
	if npc_data and npc_data.schedule:
		npc_data.schedule.current_path = null
		_check_schedule(GameState.hour, GameState.minute)

func _on_interact(object: Interactable, interact_type: String, engaged: bool):
	if object != interact_area or not engaged: return
	if interact_type == "interact":
		_handle_interaction()

func _handle_interaction():
	if npc_data.bark_only:
		_play_context_bark()
	else:
		_start_context_dialogue()

func _start_context_dialogue():
	if not interactable: return
	GameState.talking_to = null
	var timeline_to_play = npc_data.default_timeline
	for flag in npc_data.condition_timelines.keys():
		if GameState.world_flags.get(flag, false) == true:
			timeline_to_play = npc_data.condition_timelines[flag]
			break
	if timeline_to_play != "":
		DialogueManager.start_dialogue(timeline_to_play, self, npc_data.name)
	else:
		_play_context_bark()

func _play_context_bark():
	var bark_lines = npc_data.conditional_barks.get("default", [])
	if bark_lines.is_empty(): return
	spawn_bark(bark_lines.pick_random())

func spawn_bark(text: String):
	var bubble = BARK_BUBBLE.instantiate()
	get_tree().root.add_child(bubble)
	bubble.global_position = bark_anchor.global_position
	bubble.setup(text, Color.WHITE)

func follow_player(follow_npc: NPC, follow: bool):
	if follow_npc != self: return
	if follow:
		prev_state = state
		state = FOLLOWING
		GameState.leading_npc = self
	else:
		state = prev_state
		GameState.leading_npc = null
