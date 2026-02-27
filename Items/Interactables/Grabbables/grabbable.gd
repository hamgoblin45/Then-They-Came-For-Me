extends RigidBody3D
class_name Grabbable

@export var slot_data: SlotData
@export var interact_area: Interactable

var held: bool = false

func _ready():
	add_to_group("grabbables")
	# If no slot data is assigned (dragged into scene manually), create dummy data
	if not slot_data:
		push_warning("Grabbable %s has no SlotData!" % name)
		# Create dummy data so it doesn't crash, but you should fix in inspector
		return 

	# Forward interactions from the child Interactable component
	if interact_area:
		interact_area.interacted.connect(_on_interacted)

func _on_interacted(type: String, engaged: bool):
	match type:
		"click":
			if engaged:
				EventBus.item_grabbed.emit(self)
				held = true
			else:
				EventBus.item_dropped.emit()
				held = false
		
		"interact":
			_pickup_item()

func _pickup_item():
	if slot_data and slot_data.item_data:
		print("Grabbable: Picking up %s x%s" % [slot_data.item_data.name, slot_data.quantity])
		EventBus.adding_item.emit(slot_data.item_data, slot_data.quantity)
		
		# The InteractRay will detect this deletion in _physics_process 
		# and update the UI automatically.
		queue_free()
