extends Node

var daily_shop_cache: Dictionary = {}

func _ready() -> void:
	EventBus.day_changed.connect(_on_day_changed)

func _on_day_changed() -> void:
	daily_shop_cache.clear()

func get_shop_inventory(merchant_id: String, stock_config: Dictionary) -> InventoryData:
	if daily_shop_cache.has(merchant_id):
		return daily_shop_cache[merchant_id]
	
	var new_stock = _generate_daily_stock(stock_config)
	daily_shop_cache[merchant_id] = new_stock
	return new_stock

func _generate_daily_stock(config: Dictionary) -> InventoryData:
	var shop_inv = InventoryData.new()
	shop_inv.slots.resize(10) # Adjust max shop size here
	
	# SMART ADD HELPER: Stacks items and fills left-to-right to prevent gaps
	var add_to_shop = func(item: ItemData, qty: int):
		# 1. Fill existing stacks first
		if item.stackable:
			for slot in shop_inv.slots:
				if slot and slot.item_data == item:
					var space = item.max_stack_size - slot.quantity
					if space > 0:
						var to_add = min(qty, space)
						slot.quantity += to_add
						qty -= to_add
					if qty <= 0: return # Fully stacked
		
		# 2. Place remaining quantity into empty slots
		while qty > 0:
			var empty_idx = shop_inv.slots.find(null)
			if empty_idx == -1: return # Shop is completely full
			
			var new_slot = SlotData.new()
			new_slot.item_data = item
			new_slot.quantity = min(qty, item.max_stack_size) if item.stackable else 1
			
			shop_inv.slots[empty_idx] = new_slot
			qty -= new_slot.quantity

	# A. Add Guaranteed Items
	if config.has("guaranteed") and config["guaranteed"] is Array:
		for item in config["guaranteed"]:
			add_to_shop.call(item, 5) # E.g., 5 Bread

	# B. Fill Random Slots from Pool
	if config.has("pool") and config["pool"] is InventoryData:
		var pool: InventoryData = config["pool"]
		
		# Filter out nulls
		var valid_pool_items: Array[SlotData] = []
		for s in pool.slots:
			if s and s.item_data:
				valid_pool_items.append(s)
		
		if not valid_pool_items.is_empty():
			# Roll 3 to 6 random item pulls
			var rolls = randi_range(3, 6)
			
			for i in range(rolls):
				var picked_slot = valid_pool_items.pick_random()
				# Randomize quantity given to the shop based on pool quantity
				var random_qty = randi_range(1, max(1, picked_slot.quantity))
				
				add_to_shop.call(picked_slot.item_data, random_qty)
			
	return shop_inv
