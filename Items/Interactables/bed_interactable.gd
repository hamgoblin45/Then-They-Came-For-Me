extends Interactable
class_name BedInteractable

func _ready() -> void:
	super._ready() # Run Interactable's _ready()

func _on_interacted(type: String, engaged: bool):
	if type == "click" and engaged:
		print("Player is going to sleep.")
		
		# We can use the overlay to do a nice fade out/fade in without the text
		EventBus.end_day.emit()
