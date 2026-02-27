extends Node3D

@export var container_inventory: InventoryData
@onready var interactable: Interactable = $Interactable

var is_open: bool = false

func _ready():
	interactable.interacted.connect(_on_interacted)

func _on_interacted(type: String, engaged: bool):
	if type == "interact" and engaged:
		if not is_open:
			_open()
		else:
			_close()

func _open():
	is_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.ui_open = true
	EventBus.setting_external_inventory.emit(container_inventory)
	EventBus.force_ui_open.emit(true)

func _close():
	is_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameState.ui_open = false
	EventBus.setting_external_inventory.emit(null)
	EventBus.force_ui_open.emit(false)

func _unhandled_input(event: InputEvent) -> void:
	if not is_open: return
	
	# Only close on explicit cancel actions or interact
	# IMPORTANT: We handle interact here, so we must set handled to prevent double-fire
	if event.is_action_pressed("open_interface") or event.is_action_pressed("pause") or event.is_action_pressed("interact"):
		_close()
		get_viewport().set_input_as_handled()
