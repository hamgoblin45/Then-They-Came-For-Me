extends ObjectiveStepData
class_name ObjectiveStepGatherData
## Step specific to gathering a certain number of items


@export var required_items: Array[SlotData] # quantities matching required amount
var held_items: Array[SlotData]

#func _ready():
	#EventBus.item_added_to_inventory.connect(something)
	#EventBus.item_removed_from_inventory.connect(something_else)
