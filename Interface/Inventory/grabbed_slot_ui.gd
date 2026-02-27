extends PanelContainer

@onready var grabbed_item_texture: TextureRect = %GrabbedItemTexture
@onready var grabbed_quantity: Label = %GrabbedQuantity


func _ready() -> void:
	EventBus.update_grabbed_slot.connect(set_slot_data)

func _physics_process(_delta: float) -> void: # Not working, not sure why
	if visible:
		global_position = get_global_mouse_position() + Vector2(5, 5)
		

func set_slot_data(slot: SlotData):
	print("GrabbedSlotUI: Setting grabbed slot to %s" % slot)
	_clear_grabbed_slot()
	if slot == null:
		return
	
	show()
	grabbed_item_texture.texture = slot.item_data.texture
	
	if slot.quantity > 1:
		grabbed_quantity.text = str(slot.quantity)
		grabbed_quantity.show()
	
	position = get_parent().get_local_mouse_position()

func _clear_grabbed_slot():
	print("GrabbedSlotUI: clearing data")
	hide()
	grabbed_quantity.hide()
	grabbed_item_texture.texture = null
