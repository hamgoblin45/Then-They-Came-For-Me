extends Resource
class_name InventoryData

signal inventory_updated(inventory_data: InventoryData)
signal inventory_interact(inventory_data: InventoryData, index: int, button: int)

@export var slots: Array[SlotData]

func on_slot_clicked(index: int, button: int):
	inventory_interact.emit(self, index, button)

# Add item to first available slot or stack it
func add_item(item: ItemData, count: int =1) -> bool:
	# Try to stack
	for slot in slots:
		if slot and slot.item_data == item and slot.item_data.stackable:
			if slot.quantity < slot.item_data.max_stack_size:
				var space = slot.item_data.max_stack_size - slot.quantity
				var to_add = min(count, space)
				slot.quantity += to_add
				count -= to_add
				if count == 0:
					inventory_updated.emit(self)
					return true
	
	# Try to find empty slot
	for i in range(slots.size()):
		if slots[i] == null:
			var new_slot = SlotData.new()
			new_slot.item_data = item
			new_slot.quantity = count
			slots[i] = new_slot
			inventory_updated.emit(self)
			return true
	
	# Inv full
	return false
