extends PanelContainer

var slot_data: SlotData
var current_inventory: InventoryData

@onready var split_slider: HSlider = $MarginContainer/VBoxContainer/HBoxContainer/SplitSlider
@onready var split_qty: Label = $MarginContainer/VBoxContainer/HBoxContainer/SplitQty

@onready var split_button: Button = $MarginContainer/VBoxContainer/SplitButton

var mouse_on_ui: bool



func _ready() -> void:
	EventBus.open_split_stack_ui.connect(_set_split_ui)


func _set_split_ui(inv: InventoryData, slot: SlotData):
	if not slot.item_data.stackable: return
	await get_tree().create_timer(0.01).timeout
	show()
	current_inventory = inv
	slot_data = slot
	split_qty.text = "%s/%s" % [str(snappedi(split_slider.value,1)), str(slot.quantity)]
	split_slider.max_value = slot.quantity
	split_slider.value = 1
	
	_update_button_text()

func _physics_process(_delta: float) -> void:
	if !visible: return
	if Input.is_action_just_pressed("click") and not mouse_on_ui \
	or Input.is_action_just_pressed("back"):
		print("Click while split ui is visible and mouse off panel, hiding")
		hide()

func _update_button_text() -> void:
	var amount = int(split_slider.value)
	if GameState.shopping:
		var total_val = amount * slot_data.item_data.sell_value
		split_button.text = "Sell for $%s" % total_val
	else:
		split_button.text = "Split"

func _on_split_button_pressed() -> void:
	var amount = int(split_slider.value)
	
	if amount <= 0 or amount > slot_data.quantity: # Changed to allow selling full stack via split ui
		hide()
		return
	
	# Create the temporary data for the split
	var stack_data = SlotData.new()
	stack_data.item_data = slot_data.item_data
	stack_data.quantity = amount
	
	# NEW: If we are shopping, we route this to the ShopUI instead of the cursor
	if GameState.shopping:
		EventBus.selling_item.emit(stack_data) # Send to shop
		hide()
		return
		
	# --- STANDARD INVENTORY SPLIT ---
	if amount >= slot_data.quantity: 
		# If they split the max amount, don't actually split, just grab the whole thing
		hide()
		return 
		
	slot_data.quantity -= amount
	var idx = current_inventory.slots.find(slot_data)
	EventBus.inventory_item_updated.emit(current_inventory, idx)
	
	EventBus.splitting_item_stack.emit(stack_data)
	hide()


func _on_split_slider_value_changed(value: float) -> void:
	split_qty.text = "%s/%s" % [str(snappedi(value,1)), str(slot_data.quantity)]
	_update_button_text()


func _on_mouse_exited() -> void:
	print("Mouse left split UI")
	mouse_on_ui = false


func _on_mouse_entered() -> void:
	print("Mouse on split UI")
	mouse_on_ui = true
