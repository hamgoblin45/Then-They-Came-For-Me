extends Node
class_name InventoryManager

# References to Data Resources
@export var pockets_inventory_data: InventoryData
@export var external_inventory_data: InventoryData 
@export var shop_inventory_data: InventoryData 

# State Variables
var grabbed_slot_data: SlotData
var source_inventory: InventoryData # Where the grabbed slot came from
var pending_grab_slot_data: SlotData
var pending_grab_slot_ui: Control # Using Control effectively covers PanelContainer/SlotUI

var equipped_slot_data: SlotData = null

# Child References
@onready var grab_timer: Timer = %GrabTimer

func _ready() -> void:
	# 1. Connect EventBus Signals
	EventBus.inventory_interacted.connect(_on_inventory_interact)
	EventBus.adding_item.connect(_on_adding_item_request)
	EventBus.removing_item.connect(_on_removing_item_request)
	EventBus.request_pockets_inventory.connect(_on_pockets_request)
	EventBus.splitting_item_stack.connect(_split_item_stack)
	EventBus.setting_external_inventory.connect(_set_external_inventory)
	EventBus.use_equipped_item.connect(_use_equipped)
	EventBus.drop_equipped_item.connect(_drop_equipped)
	EventBus.force_ui_open.connect(_handle_open_ui)
	
	EventBus.shop_closed.connect(_on_shop_closed)
	
	# 2. Setup Initial State
	#grab_timer.timeout.connect(_on_grab_timer_timeout)
	call_deferred("_set_player_inventory")

func _set_player_inventory() -> void:
	print("InventoryManager: Setting pockets inventory")
	GameState.pockets_inventory = pockets_inventory_data
	EventBus.pockets_inventory_set.emit(pockets_inventory_data)

func _input(event: InputEvent) -> void:
	# Toggle UI
	if Input.is_action_just_pressed("open_interface"):
		var should_open = (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
		_handle_open_ui(should_open)
	
	# Stop grabbing if click released early
	if Input.is_action_just_released("click"):
		if not grab_timer.is_stopped():
			_abort_pending_grab()

	# Gameplay Inputs (Only when UI is closed AND not shopping)
	if not GameState.ui_open and not GameState.shopping:
		_handle_gameplay_input(event)

func _handle_gameplay_input(event: InputEvent) -> void:
	# Scrolling
	if event.is_action_pressed("scroll_up"):
		_scroll_hotbar(-1)
	elif event.is_action_pressed("scroll_down"):
		_scroll_hotbar(1)
	
	# Number Keys
	for i in range(6):
		if event.is_action_pressed("hotbar_" + str(i + 1)):
			_on_hotbar_select(i)
			return

	# Use Item
	if event.is_action_pressed("click"):
		_use_equipped()
	
	# Drop Item
	if event.is_action_pressed("drop"):
		_drop_equipped()

func _handle_open_ui(open: bool) -> void:
	GameState.ui_open = open
	if open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		print("Mouse visible, UI open")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		EventBus.select_item.emit(null) # Deselect context menus
		print("Mouse captured, FPS mode")

# --- HOTBAR & EQUIPPING --- #

func _on_hotbar_select(index: int) -> void:
	if index < 0 or index >= pockets_inventory_data.slots.size():
		return
	
	var new_slot = pockets_inventory_data.slots[index]
	
	# If selecting the same slot or empty, unequip
	if GameState.active_hotbar_index == index or new_slot == null or not new_slot.item_data:
		_unequip()
		return

	GameState.active_hotbar_index = index
	_equip(new_slot, index)

func _equip(slot: SlotData, index: int) -> void:
	equipped_slot_data = slot
	EventBus.hotbar_index_changed.emit(index)
	if slot and slot.item_data:
		EventBus.equipping_item.emit(slot.item_data)
		GameState.equipped_item = slot.item_data
		print("EQUIPPED ", slot.item_data.name)

func _unequip() -> void:
	GameState.active_hotbar_index = -1
	equipped_slot_data = null
	EventBus.hotbar_index_changed.emit(-1)
	EventBus.equipping_item.emit(null)
	GameState.equipped_item = null
	print("UNEQUIPPED EVERYTHING")

func _scroll_hotbar(dir: int) -> void:
	var max_slots = pockets_inventory_data.slots.size()
	if max_slots == 0: return
	
	if GameState.active_hotbar_index == -1:
		GameState.active_hotbar_index = 0 if dir > 0 else max_slots - 1
	else:
		GameState.active_hotbar_index += dir
	
	# Wrap around
	if GameState.active_hotbar_index < 0: 
		GameState.active_hotbar_index = max_slots - 1
	elif GameState.active_hotbar_index >= max_slots: 
		GameState.active_hotbar_index = 0
	
	# Equip new selection
	var new_slot = pockets_inventory_data.slots[GameState.active_hotbar_index]
	if new_slot and new_slot.item_data:
		_equip(new_slot, GameState.active_hotbar_index)
	else:
		EventBus.equipping_item.emit(null)
		equipped_slot_data = null
	
	EventBus.hotbar_index_changed.emit(GameState.active_hotbar_index)

func _use_equipped() -> void:
	if equipped_slot_data and equipped_slot_data.item_data:
		print("Using ", equipped_slot_data.item_data.name)
		# Add specific item usage logic here (e.g., eat food, shoot gun)

func _drop_equipped() -> void:
	if equipped_slot_data and equipped_slot_data.item_data:
		var dropped_data = SlotData.new()
		dropped_data.item_data = equipped_slot_data.item_data
		dropped_data.quantity = 1
		# Remove 1 from inventory
		_remove_item_from_inventory(equipped_slot_data.item_data, 1, equipped_slot_data)
		# Spawn in world
		EventBus.item_discarded.emit(dropped_data, Vector2.ZERO)

# --- INVENTORY INTERACTION (The Core Logic) --- #

func _on_inventory_interact(inv: InventoryData, slot_ui: Control, slot_data: SlotData, type: String) -> void:
	# Penalty Logic for searching
	if SearchManager.is_searching and SearchManager.current_search_inventory == inv:
		SearchManager.search_tension += 10.0
		EventBus.show_test_value.emit("search_tension", SearchManager.search_tension)

	match type:
		"shift_click":
			if slot_data and slot_data.item_data:
				_handle_quick_move(inv, slot_data)
		
		"click":
			_unequip() # Unequip functionality when messing with UI
			if grabbed_slot_data:
				_handle_drop_or_merge(inv, slot_ui, slot_data)
			else:
				_handle_selection_or_grab(slot_ui, slot_data)

		"r_click":
			_handle_right_click(inv, slot_ui, slot_data)
		
		"world_click":
			if grabbed_slot_data:
				_discard_grabbed_item()
			else:
				EventBus.select_item.emit(null)

# Helper: Left Click Logic (Start Grab or Select)
func _handle_selection_or_grab(slot_ui: Control, slot_data: SlotData) -> void:
	EventBus.select_item.emit(slot_data)
	if slot_data and slot_data.item_data:
		# Don't grab from shop, only buy (logic handled elsewhere or prevent grab)
		if slot_ui.name.contains("Shop"): return 
		
		pending_grab_slot_data = slot_data
		pending_grab_slot_ui = slot_ui
		grab_timer.start()

# Helper: Drag and Drop Completion
func _handle_drop_or_merge(inv: InventoryData, slot_ui: Control, target_slot_data: SlotData) -> void:
	# Don't drop items INTO shop slots
	if slot_ui.name.contains("Shop"): return 
	
	var target_index = slot_ui.get_index()
	
	# CASE 1: Stack Merge
	if target_slot_data and target_slot_data.item_data == grabbed_slot_data.item_data and target_slot_data.item_data.stackable:
		var space = target_slot_data.item_data.max_stack_size - target_slot_data.quantity
		if space > 0:
			var to_add = min(grabbed_slot_data.quantity, space)
			target_slot_data.quantity += to_add
			grabbed_slot_data.quantity -= to_add
			
			if grabbed_slot_data.quantity <= 0:
				grabbed_slot_data = null
			
			# Notify updates
			EventBus.inventory_item_updated.emit(inv, target_index)
			EventBus.update_grabbed_slot.emit(grabbed_slot_data)
			return

	# CASE 2: Swap or Place into Empty
	if target_slot_data:
		# Swapping: Put target into the slot we originally grabbed from
		var source_idx = source_inventory.slots.find(null)
		if source_idx != -1:
			source_inventory.slots[source_idx] = target_slot_data
			EventBus.inventory_item_updated.emit(source_inventory, source_idx)
	
	# Place the grabbed item into the new slot
	inv.slots[target_index] = grabbed_slot_data
	EventBus.inventory_item_updated.emit(inv, target_index)
	
	grabbed_slot_data = null
	source_inventory = null
	EventBus.update_grabbed_slot.emit(null)

# Helper: Right Click Logic (Single Place or Split)
func _handle_right_click(inv: InventoryData, slot_ui: Control, slot_data: SlotData) -> void:
	if inv == shop_inventory_data: return # No right click in shop
	
	if grabbed_slot_data:
		# PLACING ONE ITEM
		var index = slot_ui.get_index()
		
		# A. Place 1 into empty slot
		if slot_data == null:
			var new_slot = SlotData.new()
			new_slot.item_data = grabbed_slot_data.item_data
			new_slot.quantity = 1
			inv.slots[index] = new_slot
			
			grabbed_slot_data.quantity -= 1
			EventBus.inventory_item_updated.emit(inv, index)
			
		# B. Add 1 to existing matching stack
		elif slot_data.item_data == grabbed_slot_data.item_data:
			if slot_data.quantity < slot_data.item_data.max_stack_size:
				slot_data.quantity += 1
				grabbed_slot_data.quantity -= 1
				EventBus.inventory_item_updated.emit(inv, index)
		
		# Cleanup grabbed slot if empty
		if grabbed_slot_data.quantity <= 0:
			grabbed_slot_data = null
		
		EventBus.update_grabbed_slot.emit(grabbed_slot_data)

# --- GRAB TIMER LOGIC --- #

func _abort_pending_grab() -> void:
	print("InventoryManager: Aborting grab, treating as Click")
	grab_timer.stop()
	pending_grab_slot_data = null
	pending_grab_slot_ui = null
	EventBus.update_grabbed_slot.emit(null)

func _on_grab_timer_timeout() -> void:
	if pending_grab_slot_data:
		print("InventoryManager: Grab Confirmed")
		grabbed_slot_data = pending_grab_slot_data
		source_inventory = pending_grab_slot_ui.parent_inventory
		
		# Remove from source inventory
		var idx = source_inventory.slots.find(grabbed_slot_data)
		if idx != -1:
			source_inventory.slots[idx] = null
			EventBus.inventory_item_updated.emit(source_inventory, idx)
		
		EventBus.update_grabbed_slot.emit(grabbed_slot_data)
		EventBus.select_item.emit(null) # Close context menu
		
		pending_grab_slot_data = null
		pending_grab_slot_ui = null

# --- ADD / REMOVE / TRANSFER HELPERS --- #

func _add_item_to_inventory(inv: InventoryData, item: ItemData, qty: int) -> int:
	var remaining = qty
	print("InvManager: Adding %s %s to inv %s" % [qty, item.name, inv])
	
	# 1. Fill existing stacks
	if item.stackable:
		for i in range(inv.slots.size()):
			var slot = inv.slots[i]
			if slot and slot.item_data == item:
				var space = item.max_stack_size - slot.quantity
				if space > 0:
					var to_add = min(remaining, space)
					slot.quantity += to_add
					remaining -= to_add
					EventBus.inventory_item_updated.emit(inv, i)
					if remaining == 0: return 0

	# 2. Fill empty slots
	if remaining > 0:
		for i in range(inv.slots.size()):
			if inv.slots[i] == null:
				var new_slot = SlotData.new()
				new_slot.item_data = item
				new_slot.quantity = min(remaining, item.max_stack_size)
				inv.slots[i] = new_slot
				remaining -= new_slot.quantity
				EventBus.inventory_item_updated.emit(inv, i)
				if remaining == 0: return 0
				
	return remaining

func _remove_item_from_inventory(item_data: ItemData, qty_to_remove: int, preferred_slot: SlotData = null) -> void:
	var remaining = qty_to_remove
	
	# Try preferred slot first
	if preferred_slot and preferred_slot.item_data == item_data:
		remaining = _take_from_slot(preferred_slot, remaining)
		if remaining <= 0: 
			EventBus.select_item.emit(null)
			return

	# Search pockets
	if remaining > 0:
		for slot in pockets_inventory_data.slots:
			if slot and slot.item_data == item_data:
				remaining = _take_from_slot(slot, remaining)
				if remaining <= 0: break
	
	EventBus.select_item.emit(null)

func _take_from_slot(slot: SlotData, amount_needed: int) -> int:
	var inv = _get_inv_of_slot(slot)
	if not inv: return amount_needed
	
	var to_take = min(slot.quantity, amount_needed)
	slot.quantity -= to_take
	var still_needed = amount_needed - to_take
	
	var idx = inv.slots.find(slot)
	
	if slot.quantity <= 0:
		inv.slots[idx] = null
		if equipped_slot_data == slot:
			_unequip()
	
	EventBus.inventory_item_updated.emit(inv, idx)
	return still_needed

func _get_inv_of_slot(slot: SlotData) -> InventoryData:
	if pockets_inventory_data.slots.has(slot): return pockets_inventory_data
	if external_inventory_data and external_inventory_data.slots.has(slot): return external_inventory_data
	return null

func _handle_quick_move(source_inv: InventoryData, slot_data: SlotData) -> void:
	var dest_inv = external_inventory_data if source_inv == pockets_inventory_data else pockets_inventory_data
	if not dest_inv: return

	var remaining = _add_item_to_inventory(dest_inv, slot_data.item_data, slot_data.quantity)
	
	# Update source
	var idx = source_inv.slots.find(slot_data)
	if remaining == 0:
		source_inv.slots[idx] = null
	else:
		slot_data.quantity = remaining
	
	EventBus.inventory_item_updated.emit(source_inv, idx)
	EventBus.select_item.emit(null)

# --- MISC EVENTS --- #

func _on_adding_item_request(item_data: ItemData, qty: int) -> void:
	_add_item_to_inventory(pockets_inventory_data, item_data, qty)

func _on_removing_item_request(item_data: ItemData, qty: int, slot: SlotData) -> void:
	_remove_item_from_inventory(item_data, qty, slot)

func _set_external_inventory(inv_data: InventoryData) -> void:
	external_inventory_data = inv_data
	EventBus.external_inventory_set.emit(inv_data)

func _on_pockets_request() -> void:
	EventBus.pockets_inventory_set.emit(pockets_inventory_data)

func _split_item_stack(new_grab_data: SlotData) -> void:
	grabbed_slot_data = new_grab_data
	EventBus.update_grabbed_slot.emit(new_grab_data)
	EventBus.select_item.emit(null)

func _discard_grabbed_item() -> void:
	if grabbed_slot_data:
		EventBus.item_discarded.emit(grabbed_slot_data, Vector2.ZERO)
		grabbed_slot_data = null
		source_inventory = null
		EventBus.update_grabbed_slot.emit(null)

func _on_shop_closed() -> void:
	# Clear whatever is selected so the context menu hides and resets
	EventBus.select_item.emit(null)
	# If we want the inventory to close entirely when the shop closes:
	_handle_open_ui(false)
