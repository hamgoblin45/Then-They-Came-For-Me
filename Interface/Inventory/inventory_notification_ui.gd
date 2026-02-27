extends PanelContainer

@onready var notification_label: RichTextLabel = %NotificationLabel

@onready var anim: AnimationPlayer = $AnimationPlayer


func removed_item(item: String, qty: int): # Requests removing an item from an inventory
	print("REMOVED ITEM run")
	notification_label.text = "%s %s removed" % [str(qty), item]
	#anim.play("show")

func received_item(item: String, qty: int): # Requests adding an item to an inventory
	notification_label.text = "%s %s received" % [str(qty), item]
	#anim.play("show")

func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	queue_free()
