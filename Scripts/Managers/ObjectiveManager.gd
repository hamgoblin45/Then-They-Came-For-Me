extends Node



func _ready() -> void:
	EventBus.assign_objective.connect(_assign_objective)
	EventBus.advance_objective.connect(_advance_objective)
	EventBus.objective_completed.connect(_complete_objective) # Since completion is determined by attempting to advance, there's no request signal. This just listens for confirmation
	EventBus.turn_in_objective.connect(_turn_in_objective)
	EventBus.remove_objective.connect(_remove_objective)
	
	EventBus.inventory_item_updated.connect(_check_for_required_items)

func _assign_objective(objective: ObjectiveData):
	print("Assign objective %s received by ObjectiveManager" % objective)
	# Check if objective is already assigned, completed, or failed
	for obj in GameState.objectives:
		if obj.id == objective.id:
			print("Objective already exists in GameState")
			return
	
	objective.set_data()
	
	GameState.objectives.append(objective) # Add to GameState to be saved
	
	

func _advance_objective(objective: ObjectiveData):
	print("Advancing objective %s received by ObjectiveManager" % objective)
	for obj in GameState.objectives:
		if obj.id == objective.id:
			print("Objective match found for advance_objective in ObjectiveManager")
			obj.advance_objective()


func _complete_objective(objective: ObjectiveData):
	print("Objective %s completed acknowledged by ObjectiveManager" % objective)
	

func _turn_in_objective(objective: ObjectiveData):
	print("Objective %s turned in as acknowledge by ObjectiveManager" % objective)
	
	# Take any required items
	for step in objective.step_datas:
		if step is ObjectiveStepGatherData:
			for item_slot in step.required_items:
				EventBus.removing_item.emit(item_slot.item_data, item_slot.quantity) # This is an Inv project signal, add those or comment out to avoid crash
	
	# Give rewards
	for reward_item in objective.rewards:
		EventBus.adding_item.emit(reward_item, 1)
	
	objective.apply_consequences()
	
	objective.turned_in = true
	EventBus.objective_turned_in.emit(objective)
	
	# Assign follow-up if one exists
	if objective.follow_up_objective:
		_assign_objective(objective.follow_up_objective)

func _remove_objective(objective: ObjectiveData):
	pass

func _check_for_required_items(_slot: SlotData):
	print("Check for required items called in ObjectiveManager")
	# Checks for gather objectives
	for obj in GameState.objectives:
		var current_step = obj.current_step
		if current_step is ObjectiveStepGatherData:
			print("Current step is Gather, as acknowledged by ObjectiveManager")
			current_step.held_items.clear()
			for req_item_slot in current_step.required_items:
				
			# Checks inventory for required items
				#var amount_held: int = 0
				for slot_data in GameState.inventory.slot_datas:
					if slot_data and slot_data.item_data and slot_data.item_data.id == req_item_slot.item_data.id:
						var held_slot_data = SlotData.new()
						held_slot_data.item_data = slot_data.item_data
						held_slot_data.quantity = slot_data.quantity
						current_step.held_items.append(held_slot_data)
				# Sets objective data to reflect quantity of req item held
				#req_item_slot.quantity = amount_held
			EventBus.update_objective.emit(obj)
			
