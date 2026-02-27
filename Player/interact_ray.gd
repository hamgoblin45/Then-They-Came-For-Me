extends RayCast3D

# Track the object we are currently looking at
var current_interactable: Interactable = null

func _physics_process(_delta: float) -> void:
	if get_tree().paused: return

	# 1. Get the raw collider from the physics engine
	var collider = get_collider()
	
	# 2. VALIDATION: Check if this collider is a "Zombie" (deleted but still lingering in physics)
	if is_instance_valid(collider):
		# Case A: The object itself is being deleted
		if collider.is_queued_for_deletion():
			collider = null
		# Case B: The object's parent is being deleted (Common for Area3D attached to Grabbable)
		elif collider.get_parent() and collider.get_parent().is_queued_for_deletion():
			collider = null
	else:
		collider = null

	# 3. Holding Check: If we hold an item, we effectively see "nothing"
	if GameState.held_item:
		collider = null

	# 4. STATE CHANGE: Only run logic if what we are looking at has changed
	if collider != current_interactable:
		
		# A. Turn off the OLD UI
		# If the old object is still valid, tell it to un-highlight
		if is_instance_valid(current_interactable):
			EventBus.looking_at_interactable.emit(current_interactable, false)
		
		# *** THE FIX IS HERE ***
		# If the old object is INVALID (deleted), we still need to tell the UI to close!
		else:
			EventBus.looking_at_interactable.emit(null, false)
		
		# B. Update Internal Reference
		current_interactable = null
		
		# C. Turn on the NEW UI (if valid)
		if collider is Interactable:
			current_interactable = collider
			EventBus.looking_at_interactable.emit(current_interactable, true)


func _unhandled_input(_event: InputEvent) -> void:
	# Standardize Input Checking
	if GameState.ui_open or GameState.held_item: 
		return
	
	# Verify current_interactable is still valid before processing input
	if not is_instance_valid(current_interactable) or current_interactable.is_queued_for_deletion():
		return

	if Input.is_action_just_pressed("interact"):
		EventBus.item_interacted.emit(current_interactable, "interact", true)
	
	elif Input.is_action_just_pressed("click"):
		EventBus.item_interacted.emit(current_interactable, "click", true)
		
	elif Input.is_action_just_released("click"):
		EventBus.item_interacted.emit(current_interactable, "click", false)
		
	elif Input.is_action_just_pressed("r_click"):
		EventBus.item_interacted.emit(current_interactable, "r_click", true)
	
	elif Input.is_action_just_released("r_click"):
		EventBus.item_interacted.emit(current_interactable, "r_click", false)
