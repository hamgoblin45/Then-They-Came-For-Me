extends Control

const INVENTORY_NOTIFICATION_UI = preload("uid://hq50p18b77jj")


@onready var notification_container: VBoxContainer = $NotificationContainer


func _ready() -> void:
	EventBus.removing_item.connect(_removed_item)
	EventBus.adding_item.connect(_received_item)
	

func _removed_item(item: ItemData, qty: int, _slot: SlotData):
	var new_notif = INVENTORY_NOTIFICATION_UI.instantiate()
	notification_container.add_child(new_notif)
	await get_tree().create_timer(0.05).timeout
	new_notif.removed_item(item.name, qty)
	_handle_overflow()

func _received_item(item: ItemData, qty: int):
	var new_notif = INVENTORY_NOTIFICATION_UI.instantiate()
	notification_container.add_child(new_notif)
	new_notif.received_item(item.name, qty)
	_handle_overflow()

func _handle_overflow():
	var notifs = notification_container.get_children()
	if notifs.size() > 4:
		notifs[0].queue_free()
