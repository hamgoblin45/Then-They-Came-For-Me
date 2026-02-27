extends PanelContainer

const INVENTORY_SLOT = preload("uid://d3yl41a7rncgb")

@export var inventory_data: InventoryData

@onready var name_label: Label = %ExternalNameLabel
@onready var slot_container: GridContainer = %ExternalSlotContainer

@onready var item_context_ui: PanelContainer = %ExternalItemContextUI
@onready var split_stack_ui: PanelContainer = %ExternalSplitStackUI


func _ready() -> void:
	EventBus.external_inventory_set.connect(_set_inventory)


func _set_inventory(inv_data: InventoryData):
	inventory_data = inv_data
	for slot in slot_container.get_children():
		slot.queue_free()
	if inventory_data == null:
		hide()
		return
	show()
	#for slot in inv_data.slots:
		#var slot_ui = INVENTORY_SLOT.instantiate()
		#slot_container.add_child(slot_ui)
		#slot_ui.parent_inventory = inv_data
		#slot_ui.set_slot_data(slot)
	item_context_ui.inventory_data = inv_data
	print("ExternalInventoryUI: Set inventory w/ resource: %s" % inventory_data)
