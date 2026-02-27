extends Resource
class_name ObjectiveData
## All EventBus signals emitted from here should start with "objective_" as these are confirming the change to data took place

@export var name: String = ""
@export var id: String = ""
@export var description: String = ""

@export var step_datas: Array[ObjectiveStepData]

var current_step: ObjectiveStepData

@export_group("World Impact")
@export var suspicion_change: float = 0.0
@export var resistance_change: float = 0.0
@export var world_state_flags: Dictionary = {} # Populate with things like {neighbor_arrested: true} based on quest completion

@export var turn_in_npc: String = "" # Not sure if this is necessary but putting it here in case
var complete: bool = false
var turned_in: bool = false
var failed: bool = false

@export var rewards: Array[ItemData]
@export var follow_up_objective: ObjectiveData


func set_data():
	if step_datas.size() > 0:
		current_step = step_datas[0] # Assign first step
	EventBus.objective_assigned.emit(self)

func advance_objective():
	if !current_step:
		current_step = step_datas[0]
		return
	
	var next_step_index: int = 0
	for step in step_datas:
		if current_step.id == step.id:
			next_step_index = step_datas.find(step) + 1
			break
	
	if next_step_index >= step_datas.size():
		complete = true
		EventBus.objective_completed.emit(self)
		# When connecting to Inv, add reward items here
		return
	
	current_step = step_datas[next_step_index]
	EventBus.objective_advanced.emit(self)

func apply_consequences():
	GameState.suspicion += suspicion_change
	GameState.resistence += resistance_change
	
	for flag in world_state_flags:
		GameState.set_flag(flag, world_state_flags[flag])
