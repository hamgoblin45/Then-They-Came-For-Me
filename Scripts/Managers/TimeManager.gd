extends Node
# Handles the logic involved in controlling game time

var time_rate: float = 0.0025

func _ready() -> void:
	_start_new_day()
	handle_time()
	
	EventBus.set_paused.connect(_handle_pause)
	EventBus.change_day.connect(_change_day)
	EventBus.start_day.connect(_start_new_day)
	
	EventBus.day_changed.connect(_on_day_changed)

func handle_time():
	if GameState.paused or GameState.in_dialogue or GameState.shopping:
		return
	var prev_hour = GameState.hour
	GameState.time = 1440 * GameState.cycle_time / 60
	GameState.hour = floor(GameState.time)
	var minute_fraction = GameState.time - GameState.hour
	GameState.minute = int(60 * minute_fraction)
	
	if GameState.hour >= 24:
		GameState.cycle_time = 0.0
		GameState.hour = 0
	
	if GameState.hour > prev_hour:
		EventBus.hour_changed.emit(GameState.hour)
	#EventBus.time_changed.emit(GameState.time)
	EventBus.minute_changed.emit(GameState.hour, GameState.minute)
	#print("Hour: %s" % GameState.hour)
	#print("Minute: %s" % GameState.minute)
	#print("It is %s minute" % minute_fraction)
	
	# Only works for AM end times
	if GameState.time >= GameState.day_end and GameState.time < GameState.day_start:
		EventBus.end_day.emit()
		_handle_pause(true)


func _on_timer_timeout() -> void:
	GameState.cycle_time += time_rate * GameState.time_speed
	handle_time()

# Putting this in ScheduleData for use there but saving it just in case it makes more sense here for Time Control
#func _get_total_minutes(time_string: String) -> int:
	#var parts = time_string.split(":")
	#if parts.size() != 2: return 0
	#return(int(parts[0]) * 60) + int(parts[1]) # Breaks hours down into minutes from "HH:MM" format

func _change_day(): # Have this done during day transition
	
	
	GameState.day += 1
	
	_change_weekday()
	
	print("CHANGING DAY TO %s via TimeManager" % GameState.day)
	EventBus.day_changed.emit()
	#_start_new_day() # Have this actually run after loading back in for a new day / upon game start



func _change_weekday():
	match GameState.weekday:
		"Monday":
			GameState.weekday = "Tuesday"
		"Tuesday":
			GameState.weekday = "Wednesday"
		"Wednesday":
			GameState.weekday = "Thursday"
		"Thursday":
			GameState.weekday = "Friday"
		"Friday":
			GameState.weekday = "Saturday"
		"Saturday":
			GameState.weekday = "Sunday"
		"Sunday":
			GameState.weekday = "Monday"

func _on_day_changed():
	# 1. Reset the math variables
	_start_new_day()
	# 2. Force an immediate update so GameState.hour and GameState.minute are correct!
	handle_time()

func _start_new_day():
	print("Setting up new day in TimeManager")
	GameState.time = GameState.day_start # in hours
	GameState.cycle_time = GameState.time / 24
	EventBus.set_paused.emit(false)
	#GameState.cycle_time = 0.33 # between 0.0 and 1.0
	#EventBus.new_day_started.emit()



func _handle_pause(paused: bool):
	print("Pause handled in TimeManager")
	get_tree().paused = paused

func handle_lights():
	if GameState.time >= 17.5 or GameState.time < 6.0:
		for lamp in get_tree().get_nodes_in_group("lamps"):	
			lamp.light_on()
	else:
		for lamp in get_tree().get_nodes_in_group("lamps"):	
			lamp.light_off()
