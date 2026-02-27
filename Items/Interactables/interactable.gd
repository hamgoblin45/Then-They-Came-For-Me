extends Area3D
class_name Interactable

const INTERACT_OUTLINE = preload("uid://c3rhvr6bla26v") # Ensure path is correct

@export_group("Settings")
@export var id: String = ""
@export var interact_icon: Texture2D
@export var interact_text: String = "Interact"
@export var show_highlight: bool = true

@export_group("Visuals")
## If empty, script will attempt to find meshes in parent automatically
@export var target_meshes: Array[MeshInstance3D] 

signal interacted(type: String, engaged: bool)

func _ready() -> void:
	EventBus.item_interacted.connect(_on_interacted_event)
	EventBus.looking_at_interactable.connect(_on_look_change)
	
	if target_meshes.is_empty():
		_find_meshes_recursive(get_parent())

# Recursively finds all meshes in the parent node to apply outlines to
func _find_meshes_recursive(node: Node):
	if node is MeshInstance3D:
		target_meshes.append(node)
	
	for child in node.get_children():
		if child != self: # Don't look inside yourself
			_find_meshes_recursive(child)

func _on_interacted_event(object: Interactable, type: String, engaged: bool):
	if object != self: return
	
	# print("%s detected on %s: %s" % [type, self.name, engaged])
	interacted.emit(type, engaged)

func _on_look_change(interact: Interactable, looking: bool):
	if interact != self: return
	
	if not show_highlight: return
	
	var mat = INTERACT_OUTLINE if looking else null
	
	for mesh in target_meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = mat
