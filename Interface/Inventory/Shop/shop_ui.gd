extends PanelContainer
class_name ShopUI

const SHOP_SLOT_UI = preload("uid://cj1cyf80hrqb4")

var shop_inventory_data: InventoryData
var selected_slot: SlotData = null
var legal_buyback_slot: SlotData = null
var illegal_buyback_slot: SlotData = null
var legal: bool = true

@onready var shop_item_name: Label = %ShopItemName
@onready var shop_item_descript: RichTextLabel = %ShopItemDescript
@onready var shop_flavor_text: RichTextLabel = %ShopFlavorText
@onready var shop_item_value: Label = %ItemValue
@onready var buy_qty_slider: HSlider = %BuyQtySlider
@onready var buy_qty: Label = %BuyQty

@onready var slot_container: GridContainer = %BuySlotContainer
@onready var item_context_ui: PanelContainer = %ShopItemContextUI

@onready var buyback_ui: PanelContainer = %BuybackUI
@onready var buyback_item_texture: TextureRect = %BuybackItemTexture
@onready var buyback_quantity: Label = %BuybackQuantity
@onready var buyback_price_label: Label = %BuybuackPriceLabel

func _ready():
	EventBus.open_specific_shop.connect(_on_open_specific_shop)
	EventBus.select_item.connect(_on_item_select)
	EventBus.selling_item.connect(_sell_item)
	hide()

func _on_open_specific_shop(inv_data: InventoryData, is_legal: bool):
	GameState.shopping = true
	visible = true
	legal = is_legal
	shop_inventory_data = inv_data
	
	_clear_selected_item()
	_populate_grid(shop_inventory_data)
	
	# NEW: Tell InventorySlotUIs to update their appearance
	EventBus.shopping.emit(is_legal)
	
	if legal:
		print("ShopUI: Displaying Legal Stock")
	else:
		print("ShopUI: Displaying Black Market Stock")

func _populate_grid(inv: InventoryData):
	for child in slot_container.get_children():
		child.queue_free()
	
	for slot_data in inv.slots:
		var slot_ui = SHOP_SLOT_UI.instantiate()
		slot_container.add_child(slot_ui)
		slot_ui.parent_inventory = inv 
		if slot_data:
			slot_ui.set_slot_data(slot_data)

func _clear_selected_item():
	selected_slot = null
	item_context_ui.hide()
	buy_qty_slider.hide()
	buy_qty.hide()

func _on_item_select(slot_data: SlotData):
	if not visible: return
	
	if not slot_data or not slot_data.item_data:
		_clear_selected_item()
		return
		
	if not shop_inventory_data.slots.has(slot_data):
		_clear_selected_item()
		return
		
	selected_slot = slot_data
	item_context_ui.show()
	
	shop_item_name.text = slot_data.item_data.name
	shop_item_descript.text = slot_data.item_data.description
	# shop_flavor_text.text = slot_data.item_data.flavor_text # Uncomment if you have this property
	
	# Setup Buying Slider
	var price = slot_data.item_data.buy_value
	var can_afford = floor(GameState.money / max(1, price))
	
	buy_qty_slider.min_value = 1
	buy_qty_slider.max_value = min(slot_data.quantity, can_afford)
	buy_qty_slider.value = 1
	
	if not slot_data.item_data.stackable:
		buy_qty_slider.hide()
	else:
		buy_qty_slider.show()
	
	_update_price_display()

func _update_price_display():
	if not selected_slot: return
	var qty = int(buy_qty_slider.value)
	var cost = selected_slot.item_data.buy_value * qty
	
	shop_item_value.text = "Buy %s: $%s" % [qty, cost]
	shop_item_value.modulate = Color.RED if cost > GameState.money else Color.WHITE

func _on_buy_button_pressed():
	if not selected_slot: return
	var qty = int(buy_qty_slider.value)
	var cost = selected_slot.item_data.buy_value * qty
	
	if GameState.money >= cost:
		GameState.money -= cost
		EventBus.money_updated.emit(GameState.money)
		
		# Add to player
		EventBus.adding_item.emit(selected_slot.item_data, qty)
		
		# Remove from shop
		selected_slot.quantity -= qty
		if selected_slot.quantity <= 0:
			var idx = shop_inventory_data.slots.find(selected_slot)
			shop_inventory_data.slots[idx] = null
			_clear_selected_item()
		
		_populate_grid(shop_inventory_data) 

# --- SELLING ---

func _sell_item(sell_slot: SlotData):
	if not visible: return
	
	# Determine actual quantity (force 1 if non-stackable)
	var qty = sell_slot.quantity if sell_slot.item_data.stackable else 1
	var value = sell_slot.item_data.sell_value * qty
	
	# FIX: Create a BRAND NEW memory reference for the buyback slot
	var buyback_data = SlotData.new()
	buyback_data.item_data = sell_slot.item_data
	buyback_data.quantity = qty
	
	if legal:
		legal_buyback_slot = buyback_data
	else:
		illegal_buyback_slot = buyback_data
	
	_update_buyback_ui(buyback_data)
	
	GameState.money += value
	EventBus.money_updated.emit(GameState.money)
	EventBus.removing_item.emit(sell_slot.item_data, qty, sell_slot)

func _update_buyback_ui(slot: SlotData):
	buyback_ui.show()
	buyback_item_texture.texture = slot.item_data.texture
	buyback_quantity.text = str(slot.quantity)
	buyback_price_label.text = "$%s" % (slot.item_data.sell_value * slot.quantity)

func _on_buyback_button_pressed():
	var slot = legal_buyback_slot if legal else illegal_buyback_slot
	if not slot: return
	
	var cost = slot.item_data.sell_value * slot.quantity
	if GameState.money >= cost:
		GameState.money -= cost
		EventBus.money_updated.emit(GameState.money)
		EventBus.adding_item.emit(slot.item_data, slot.quantity)
		
		if legal: legal_buyback_slot = null
		else: illegal_buyback_slot = null
		
		buyback_ui.hide()

func _on_close_shop_button_pressed():
	GameState.shopping = false
	visible = false
	buyback_ui.hide()
	EventBus.shop_closed.emit()
