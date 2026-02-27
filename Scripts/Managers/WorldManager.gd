extends Node

var world_schedule = {
	# EXAMPLE
	# The day the following schedule occurs
	# 2: {
	#	"flags": {"checkpoint_vandalized": true, "teenager_hiding": true},
	#	"description": "The checkpoint has been vandalized and the Enforcers are hunting the culprit"
	#},
	# ... # Add rest of days here
}


func _ready() -> void:
	EventBus.day_changed.connect(_on_day_changed)
	_apply_world_state(GameState.day)

func _on_day_changed(new_day: int):
	_apply_world_state(new_day)

func _apply_world_state(day: int):
	# Keep default if no changes
	if not world_schedule.has(day):
		return
	
	var state = world_schedule[day]
	
	if "flags" in state:
		for flag in state["flags"]:
			GameState.world_flags[flag] = state["flags"][flag]
			EventBus.world_changed.emit(flag, state["flags"][flag])
	
	print("WorldManager: Day %s initiated. Description: %s" % [day, state.get("description", "")])

func trigger_raid_sequence():
	# Play a heavy banging knocking sound
	# Start a UI timer
	var countdown = 20.0
	
	while countdown > 0:
		#update_ui_timer(countdown)
		await get_tree().create_timer(1.0).timeout
		countdown -= 1
		
		#if player_opened_door: break # Also consider a "bonus" for complying
		
