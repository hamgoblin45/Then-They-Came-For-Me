extends PanelContainer

var parent_inventory: InventoryData

@export var slot_data: SlotData

@onready var item_texture: TextureRect = %ItemTexture
@onready var quantity: Label = %Quantity
@onready var selected_panel: Panel = %SelectedPanel


func set_slot_data(new_data: SlotData):
	slot_data = new_data
	_update_visuals()

func _update_visuals():
	if not slot_data or not slot_data.item_data:
		item_texture.hide()
		quantity.hide()
		return

	item_texture.show()
	item_texture.texture = slot_data.item_data.texture
	tooltip_text = "%s ($%s)" % [slot_data.item_data.name, slot_data.item_data.buy_value]
	
	if slot_data.quantity > 1:
		quantity.show()
		quantity.text = str(slot_data.quantity)
	else:
		quantity.hide()

## -- Remove from slot
func clear_visuals():
	item_texture.hide()
	quantity.hide()
	tooltip_text = ""

func clear_slot_data(slot: SlotData):
	if slot and slot != slot_data: return # Verify this slot is the right one
	
	print("Clear slot run on InventorySlotUI. Slot: %s" % slot)
	item_texture.texture = null
	slot_data = null
	clear_visuals()
	
	EventBus.inventory_item_updated.emit(null)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_LEFT:
			EventBus.inventory_interacted.emit(parent_inventory, self, slot_data, "click")
			EventBus.select_item.emit(slot_data)
			#print("Shop UI slot clicked")
		if event.button_index == MOUSE_BUTTON_RIGHT:
			EventBus.inventory_interacted.emit(parent_inventory, self, slot_data, "r_click")
