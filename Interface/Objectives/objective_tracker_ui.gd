extends PanelContainer


const OBJECTIVE_UI = preload("uid://b4q0h7ka7r6wv")


@onready var objective_container: VBoxContainer = %ObjectiveContainer


func _ready():
	EventBus.objective_assigned.connect(_on_objective_assigned)
	EventBus.objective_advanced.connect(_on_objective_advanced)
	EventBus.update_objective.connect(_on_objective_updated)

func _on_objective_assigned(objective: ObjectiveData):
	print("Objective assignment received by ObjectiveTrackerUI")
	var objective_ui = OBJECTIVE_UI.instantiate()
	objective_container.add_child(objective_ui)
	objective_ui.set_objective_data(objective)

func _on_objective_advanced(objective: ObjectiveData):
	print("Objective advancement received by ObjectiverTrackerUI")
	# Nothing should actually be needed here as each Objective UI tracks its own advance signal
	#for obj_ui in objective_container.get_children():
		#if obj_ui.objective_data.id == objective.id:
			#

func _on_objective_updated(objective: ObjectiveData):
	print("Update objective signal received by ObjectiveTrackerUI")
	for obj_ui in objective_container.get_children():
		if obj_ui.objective_data.id == objective.id:
			obj_ui.set_objective_data(objective)
