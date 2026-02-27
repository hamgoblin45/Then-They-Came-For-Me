extends Control

const INVENTORY_SLOT = preload("uid://d3yl41a7rncgb")

@export var inventory_data: InventoryData

@onready var slot_container: GridContainer = %PocketSlotContainer

@onready var item_context_ui: PanelContainer = %PocketItemContextUI
@onready var split_stack_ui: PanelContainer = %PocketsSplitStackUI

@onready var money_value: Label = %MoneyValue


func _ready() -> void:
	EventBus.pockets_inventory_set.connect(_set_inventory)
	EventBus.money_updated.connect(_update_money)
	EventBus.request_pockets_inventory.emit()

func _set_inventory(inv_data: InventoryData):
	money_value.text = str(snapped(GameState.money, 0.1))
	item_context_ui.inventory_data = inv_data
	print("PocketsInventoryUI: Set inventory w/ resource: %s" % inventory_data)


func _update_money(value: float):
	money_value.text = str(snapped(value, 0.01))
