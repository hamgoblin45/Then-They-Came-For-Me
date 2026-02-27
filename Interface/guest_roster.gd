extends PanelContainer

@onready var roster_list: VBoxContainer = $VBoxContainer/RosterList
@onready var notification_label: Label = $NotificationLabel

func _ready():
	GuestManager.guest_added.connect(_on_guest_added)
	GuestManager.guest_removed.connect(_on_guest_removed)
	GuestManager.guest_notification.connect(_show_notification)
	
	if notification_label:
		notification_label.hide()

func _on_guest_added(npc_data: NPCData):
	var label = Label.new()
	label.text = "- " + npc_data.name
	label.name = npc_data.name # Name the node so we can find it to remove it later
	roster_list.add_child(label)

func _on_guest_removed(npc_data: NPCData):
	for child in roster_list.get_children():
		if child.name == npc_data.name:
			child.queue_free()

func _show_notification(message: String):
	if not notification_label: return
	
	notification_label.text = message
	notification_label.show()
	notification_label.modulate.a = 1.0
	
	# Fade out after 3 seconds
	var tween = create_tween()
	tween.tween_property(notification_label, "modulate:a", 0.0, 1.5).set_delay(3.0)
	tween.tween_callback(notification_label.hide)
