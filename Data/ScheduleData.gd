extends Resource
class_name ScheduleData

# key: "HH:MM", value: PathData
@export var default_routine: Dictionary = {}

# Alternative routines are triggered by World Flags
@export var alternative_routines: Dictionary = {}

var current_path: PathData

## Find the next scheduled path based on time
func get_path_for_time(hour: int, minute: int) -> PathData:
	#print("get_path_for_time run in ScheduleData")
	var current_total = (hour * 60) + minute
	var active_routine = default_routine # Set default if nothing else gets added
	
	# Check world flags
	for flag_name in alternative_routines.keys():
		if GameState.world_flags.get(flag_name, false) == true:
			active_routine = alternative_routines[flag_name]
			break # First matching flag wins (Adjust this to have some sort of priority logic)
	
	# Find best path in active routine
	var best_match_minutes: int = -1
	var selected_path: PathData = null
	
	for time_key in active_routine.keys():
		var task_minutes = _get_total_minutes(time_key)
		# Find the most recent task that has already been started
		if current_total >= task_minutes and task_minutes > best_match_minutes and best_match_minutes != task_minutes:
			best_match_minutes = task_minutes
			selected_path = active_routine[time_key]
			print("A new path selected based on time in ScheduleData")
	return selected_path

func _get_total_minutes(time_string: String) -> int:
	var parts = time_string.split(":")
	if parts.size() != 2: return 0
	return(int(parts[0]) * 60) + int(parts[1]) # Breaks hours down into minutes from "HH:MM" format
