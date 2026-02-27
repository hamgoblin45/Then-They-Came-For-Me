extends PanelContainer

var inventory_data: InventoryData
var slot_data


@export var item_name: Label
@export var item_descript: RichTextLabel
@export var item_flavor_text: RichTextLabel
@onready var item_value: Label = %ItemValue


@export var trash_button: Button
@export var use_button: Button
@export var split_button: Button
@export var drop_button: Button

var mouse_on_ui: bool = false
var trash_confirmed: bool = false


func set_context_menu(slot: SlotData):
	if not slot or not slot.item_data or not inventory_data:
		_clear_out_context_ui()
		return
	
	# Checks if item is in correlating inventory
	if not inventory_data or not inventory_data.slots.has(slot):
		hide()
		return
	
	if trash_button:
		trash_confirmed = false
		trash_button.text = "TRASH"
		trash_button.modulate = Color.WHITE
	
	split_button.hide()
	use_button.hide()
	
	show()
	slot_data = slot
	
	print("ItemContextUI: set_context_menu: Setting context UI to %s in inv: %s" % [slot, inventory_data])
	item_name.text = slot_data.item_data.name
	item_descript.text = "[center]" + slot_data.item_data.description
	item_flavor_text.text = "[center]" + slot_data.item_data.flavor_text
	
	drop_button.show()
	
	# Prevent dropping from external inventories
	if inventory_data != GameState.pockets_inventory:
		drop_button.hide()
	
	item_value.text = str(slot_data.item_data.sell_value)
	if slot_data.item_data.stackable and slot_data.quantity > 1 and split_button:
		split_button.show()
	if slot_data.item_data.useable or GameState.shopping:
		use_button.show()
		if GameState.shopping:
			use_button.text = "SELL"
			
		elif GameState.in_dialogue:
			use_button.text = "GIVE"
		else:
			use_button.text = "USE"
	



func _clear_out_context_ui():
	if trash_button:
		trash_confirmed = false
		trash_button.text = "TRASH"
		trash_button.modulate = Color.WHITE # Reset trash button color
	slot_data = null
	hide()


func _on_trash_button_pressed() -> void:
	if not trash_confirmed:
		# First click: ask to confirm trash
		trash_confirmed = true
		trash_button.text = "SURE?"
		trash_button.modulate = Color.RED
	else:
		# Second click: actually removes
		EventBus.removing_item.emit(slot_data.item_data, slot_data.quantity, slot_data)
		_clear_out_context_ui()

func _on_use_button_pressed() -> void:
	match use_button.text:
		"USE":
			EventBus.using_item.emit(slot_data)
		"GIVE":
			EventBus.giving_item.emit(slot_data)
		"SELL":
			# NEW: Check if stackable before selling immediately
			if slot_data.item_data.stackable and slot_data.quantity > 1:
				EventBus.open_split_stack_ui.emit(inventory_data, slot_data)
			else:
				EventBus.selling_item.emit(slot_data)

func _on_split_button_pressed() -> void:
	EventBus.open_split_stack_ui.emit(inventory_data, slot_data)
	print("Split button pressed on Context Menu")

func _on_hide_details_button_pressed() -> void:
	_clear_out_context_ui()


func _on_drop_button_pressed() -> void:
	EventBus.removing_item.emit(slot_data.item_data, slot_data.quantity, slot_data)
	
	EventBus.item_discarded.emit(slot_data, get_global_mouse_position())
	
	_clear_out_context_ui()
