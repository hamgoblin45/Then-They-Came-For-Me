extends PanelContainer
## Just control UI, logic should be handled in the ObjectiveManager

const OBJECTIVE_STEP_UI = preload("uid://btcdsfmx1knfj")

@export var objective_data: ObjectiveData

@onready var objective_name: Label = %ObjectiveName
@onready var objective_description: RichTextLabel = %ObjectiveDescription

@onready var steps_container: VBoxContainer = %StepsContainer

@onready var anim: AnimationPlayer = %AnimationPlayer


func set_objective_data(objective: ObjectiveData):
	print("Setting objective data via ObjectiveUI")
	# clear out any potential lingering steps
	for child in steps_container.get_children():
		child.queue_free()
	
	objective_data = objective
	
	# Set UI
	objective_name.text = objective.name
	objective_description.text = objective.description
	
	_set_current_step(objective.current_step)
	
	anim.play("show_highlight")
	
	EventBus.objective_advanced.connect(_on_step_advanced)
	EventBus.objective_completed.connect(_on_objective_complete)
	EventBus.objective_turned_in.connect(_on_objective_turned_in)

func _set_current_step(step: ObjectiveStepData):
	print("Setting current step via ObjectiveUI")
	# Clear out previous step from UI
	for child in steps_container.get_children():
		child.queue_free()
	
	var new_step_ui = OBJECTIVE_STEP_UI.instantiate()
	steps_container.add_child(new_step_ui)
	new_step_ui.set_step_data(step)

func _on_step_advanced(objective: ObjectiveData):
	if objective.id == objective_data.id:
		print("step advance acknowledged in objective_ui. Objective: %s, Current Step: %s" % [objective, objective.current_step])
		
		_set_current_step(objective_data.current_step)
		anim.play("show_highlight")
	

func _on_objective_complete(objective: ObjectiveData):
	if objective.id == objective_data.id:
		objective_name.text = objective.name
		objective_description.text = "Ready to turn in"
		anim.play("show_highlight")
		#remove Steps from ui
		for child in steps_container.get_children():
			child.queue_free()

func _on_objective_turned_in(objective: ObjectiveData):
	if objective.id == objective_data.id:
		print("Objective turned in acknowledged by its ObjectiveUI")
		anim.play("turn_in")
		# This is where getting rewards would be displayed, as well as this panel fading out
		await anim.animation_finished
		queue_free()
