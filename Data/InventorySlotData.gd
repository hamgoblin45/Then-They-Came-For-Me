extends Resource
class_name SlotData

@export var item_data: ItemData
const MAX_STACK_SIZE: int = 99
@export_range(1, MAX_STACK_SIZE) var quantity: int = 1: set = set_quantity

func set_quantity(value: int):
	quantity = value
	if quantity > 1 and not item_data.stackable:
		quantity = 1
		push_warning("Tried to stack unstackable item %s" % item_data.name)

func can_merge_with(other_slot_data: SlotData) -> bool:
	return item_data == other_slot_data.item_data and item_data.stackable and quantity < item_data.max_stack_size

func can_fully_merge_with(other_slot_data: SlotData) -> bool:
	return can_merge_with(other_slot_data) and (quantity + other_slot_data.quantity) <= item_data.max_stack_size

func fully_merge_with(other_slot_data: SlotData):
	quantity += other_slot_data.quantity

func _is_empty() -> bool:
	return item_data == null or quantity <= 0

func duplicate_slot() -> SlotData:
	var new_slot = SlotData.new()
	new_slot.item_data = item_data
	new_slot.quantity = quantity
	return new_slot
