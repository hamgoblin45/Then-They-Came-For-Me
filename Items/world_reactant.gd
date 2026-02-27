extends Node3D


@export var required_flag: String = ""
# Below is example of a way the world can react to world flags but isn't the only way;
# set up state changes and transforms and such as well
@export var hide_if_flag_true: bool = true # If true, whatever this is attached to will vanish if the flag is true


func _ready():
	_update_visibility()
	
	EventBus.world_changed.connect(_on_world_changed)
	

func _on_world_changed(flag_name: String, _value: bool):
	if flag_name == required_flag:
		_update_visibility()

func _update_visibility():
	if required_flag == "": return
	
	var flag_status = GameState.world_flags.get(required_flag, false)
	
	if hide_if_flag_true:
		get_parent().visible = !flag_status
		# Disable collisions if hidden -- WHy not just queuefree? Becuase it can't show again if it's gone; useful for someone going into a house, then back out or something
		process_mode = Node.PROCESS_MODE_INHERIT if !flag_status else PROCESS_MODE_DISABLED
	else:
		get_parent().visible = !flag_status
		# Re-enable collisions if shown -- WHy not just queuefree?
		process_mode = Node.PROCESS_MODE_INHERIT if !flag_status else PROCESS_MODE_DISABLED
