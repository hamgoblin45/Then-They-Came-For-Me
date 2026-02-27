extends PanelContainer
class_name SlotUI

var parent_inventory: InventoryData
@export var slot_data: SlotData

@onready var item_texture: TextureRect = %ItemTexture
@onready var quantity: Label = %Quantity

@onready var selected_panel: Panel = %SelectedPanel
@onready var equip_highlight: Panel = %EquipHighlight
@onready var search_vignette: ColorRect = %SearchVignette
@onready var search_eye: TextureProgressBar = $SearchEye

@onready var hotbar_number: Label = %HotbarNumber
var slot_index: int = 0

var activated: bool = true
var tween: Tween
var pulse_tween: Tween # NEW: Dedicated tween for the heartbeat pulse
var base_eye_pos: Vector2 = Vector2.ZERO

enum SearchState {NONE, PENDING, SEARCHING, CLEARED}
var current_search_state = SearchState.NONE

func _ready() -> void:
	EventBus.inventory_item_updated.connect(_on_item_updated)
	EventBus.select_item.connect(_select_item)
	EventBus.hotbar_index_changed.connect(_on_equipped_changed)
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	EventBus.shopping.connect(_check_if_sellable)
	EventBus.shop_closed.connect(_on_shop_closed)
	
	SearchManager.search_step_started.connect(_on_search_step)
	SearchManager.search_finished.connect(_on_search_finished)
	SearchManager.search_busted_visuals.connect(_on_busted_visuals)
	DialogueManager.dialogue_ended.connect(_clear_interrogation_state)
	
	await get_tree().process_frame
	if search_eye:
		search_eye.hide()
		search_eye.pivot_offset = search_eye.size / 2.0
		base_eye_pos = search_eye.position

# REMOVED the _process(delta) function entirely!

func set_slot_data(new_slot_data: SlotData):
	slot_data = new_slot_data
	_update_visuals()
	if parent_inventory == GameState.pockets_inventory:
		equip_highlight.visible = (get_index() == GameState.active_hotbar_index)

func _select_item(data: SlotData):
	selected_panel.visible = (data == slot_data and data != null)

func _on_item_updated(inv_data: InventoryData, index: int):
	if inv_data == parent_inventory and index == get_index():
		selected_panel.hide()
		var new_data = parent_inventory.slots[index]
		if new_data == null or new_data.quantity <= 0:
			clear_slot_data(null)
		else:
			set_slot_data(new_data)
			_update_visuals()

func _update_visuals():
	if not slot_data or not slot_data.item_data:
		item_texture.hide()
		quantity.hide()
		return
		
	item_texture.show()
	item_texture.texture = slot_data.item_data.texture
	
	if slot_data.quantity > 1 and slot_data.item_data.stackable:
		quantity.show()
		quantity.text = str(slot_data.quantity)
	else:
		quantity.hide()

func _on_mouse_entered():
	if !selected_panel.visible:
		modulate = Color(1.2, 1.2, 1.2)

func _on_mouse_exited():
	modulate = Color(1,1,1)

func clear_visuals():
	selected_panel.hide()
	item_texture.hide()
	quantity.hide()
	tooltip_text = ""

func clear_slot_data(_slot: SlotData):
	slot_data = null
	item_texture.texture = null
	clear_visuals()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and activated:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if Input.is_key_pressed(KEY_SHIFT):
				EventBus.inventory_interacted.emit(parent_inventory, self, slot_data, "shift_click")
			else:
				EventBus.inventory_interacted.emit(parent_inventory, self, slot_data, "click")
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			EventBus.inventory_interacted.emit(parent_inventory, self, slot_data, "r_click")

func _on_equipped_changed(active_index: int):
	if parent_inventory == GameState.pockets_inventory:
		var is_active = (get_index() == active_index)
		equip_highlight.visible = is_active
		_animate_selection(is_active)
	else:
		equip_highlight.hide()

func _animate_selection(is_active: bool):
	if tween: tween.kill()
	tween = create_tween()
	var target_scale = Vector2(1.15,1.15) if is_active else Vector2(1.0, 1.0)
	tween.set_trans(tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", target_scale, 0.2)

func _check_if_sellable(legal_shop: bool):
	if not slot_data or not slot_data.item_data: return
	var is_contraband = slot_data.item_data.contraband_level > GameState.legal_threshold
	var can_sell = false
	if legal_shop and not is_contraband: can_sell = true
	elif not legal_shop and is_contraband: can_sell = true
	
	if not can_sell:
		activated = false
		item_texture.modulate = Color(0.2, 0.2, 0.2, 0.5)
		tooltip_text = "Merchant won't buy this"
	else:
		activated = true
		item_texture.modulate = Color.WHITE
		tooltip_text = slot_data.item_data.name

func _on_shop_closed():
	if not slot_data or not slot_data.item_data: return
	activated = true
	if item_texture: item_texture.modulate = Color.WHITE
	if slot_data and slot_data.item_data:
		tooltip_text = slot_data.item_data.name

func _on_search_step(search_inv: InventoryData, index: int, duration: float):
	if search_inv != parent_inventory: return
	if index == get_index():
		_set_search_visual(SearchState.SEARCHING, duration)
	elif index < get_index() and SearchManager.is_searching:
		_set_search_visual(SearchState.PENDING)
	elif index > get_index():
		_set_search_visual(SearchState.CLEARED)

func _set_search_visual(state: SearchState, duration: float = 0.0):
	current_search_state = state
	
	if tween and tween.is_valid(): tween.kill()
	if pulse_tween and pulse_tween.is_valid(): pulse_tween.kill() # Stop heartbeat if changing state
	
	match state:
		SearchState.PENDING:
			search_vignette.show()
			search_vignette.color = Color(0,0,0, 0.6)
			search_vignette.scale = Vector2(1,1)
			if search_eye: search_eye.hide()
			
		SearchState.SEARCHING:
			search_vignette.show()
			search_vignette.color = Color(0,0,0, 0.6)
			
			if search_eye:
				search_eye.show()
				search_eye.value = 0
				search_eye.scale = Vector2(1.0, 1.0)
				
				# 1. Linear Eye Opening
				tween = create_tween()
				tween.tween_property(search_eye, "value", 100, duration)
				
				# 2. Continuous Heartbeat Pulse
				pulse_tween = create_tween().set_loops()
				pulse_tween.tween_property(search_eye, "scale", Vector2(1.15, 1.15), 0.25).set_trans(Tween.TRANS_SINE)
				pulse_tween.tween_property(search_eye, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_SINE)
			
		SearchState.CLEARED:
			search_vignette.show()
			search_vignette.color = Color(0.3,1,0.3,0.2)
			search_vignette.scale = Vector2(1,1)
			if search_eye: search_eye.hide()
		
		SearchState.NONE:
			search_vignette.hide()
			if search_eye: 
				search_eye.hide()
				search_eye.modulate = Color.WHITE

func _on_search_finished(caught: bool, item: ItemData, qty: int, index: int = -1):
	# Always return to normal when search fully concludes
	_set_search_visual(SearchState.NONE)

func _on_busted_visuals(busted_index: int):
	if busted_index == get_index():
		if tween and tween.is_valid(): tween.kill()
		if pulse_tween and pulse_tween.is_valid(): pulse_tween.kill()
			
		search_vignette.color = Color(1, 0, 0, 0.5)
		
		if search_eye:
			search_eye.modulate = Color.RED
			search_eye.value = 100 
			
			search_eye.scale = Vector2(1.6, 1.6) 
			tween = create_tween()
			tween.tween_property(search_eye, "scale", Vector2(1.15, 1.15), 0.3)\
				.set_trans(Tween.TRANS_BOUNCE)\
				.set_ease(Tween.EASE_OUT)
		
		EventBus.request_screen_shake.emit(0.3, 0.4)

func _clear_interrogation_state():
	if current_search_state != SearchState.NONE:
		_set_search_visual(SearchState.NONE)
