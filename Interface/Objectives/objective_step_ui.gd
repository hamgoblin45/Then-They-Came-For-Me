extends PanelContainer

@export var step_data: ObjectiveStepData

@onready var step_label: RichTextLabel = %StepLabel
@onready var step_progress_label: RichTextLabel = %StepProgressLabel


func set_step_data(step: ObjectiveStepData):
	print("Setting step data in objective_step_ui")
	step_data = step
	step_label.text = step.text
	
	# If step involves gathering, displays how many are held vs how many required
	if step is ObjectiveStepGatherData:
		step_progress_label.show()
		var strings = ""
		for slot in step.required_items:
			var string = "%s: %s/%s" % [slot.item_data.name, str(0), slot.quantity]
			print("Current step requires %s %s" % [slot.item_data.name, slot.quantity])
			for held_slot in step.held_items:
				
				if slot.item_data.id == held_slot.item_data.id:
					print("required item found in inventory")
					
					string = "%s: %s/%s" % [slot.item_data.name, held_slot.quantity, slot.quantity]
					
			strings += "[p]" + string
		step_progress_label.text = strings
