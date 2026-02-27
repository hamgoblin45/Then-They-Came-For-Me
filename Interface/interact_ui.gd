extends PanelContainer

@onready var interact_label: RichTextLabel = %InteractLabel
@onready var interact_icon: TextureRect = %InteractIcon

# NEW: Keep track of what we are looking at locally
var current_interactable: Interactable = null

func _ready() -> void:
	# NEW: Force this UI to keep thinking even when the game is paused!
	process_mode = Node.PROCESS_MODE_ALWAYS 
	hide()
	EventBus.looking_at_interactable.connect(_set_interact_ui)

func _process(_delta: float) -> void:
	# 1. Suppress the UI if ANY menu or cinematic state is active
	if GameState.paused or GameState.in_dialogue or GameState.shopping or GameState.ui_open:
		hide()
	# 2. Otherwise, if we are still looking at a valid object, show it!
	elif is_instance_valid(current_interactable):
		show()
	else:
		hide()

func _set_interact_ui(interactable: Interactable, looking: bool):
	# Update check: Also check is_queued_for_deletion
	if not looking or not is_instance_valid(interactable) or interactable.is_queued_for_deletion():
		current_interactable = null
		hide()
		return
	
	current_interactable = interactable
	
	if interactable.interact_icon:
		interact_icon.texture = interactable.interact_icon
		interact_icon.show()
	else:
		interact_icon.hide()
		
	interact_label.text = "[center]" + interactable.interact_text
