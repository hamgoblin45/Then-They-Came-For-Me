extends Node

var prev_status_check: float = 0.0
var prev_satiety_check: float = 0.0

@onready var recovery_delay_timer: Timer = %RecoveryDelayTimer
var stamina_recovery_delay: float = 3.0 # How long after last action before stamina will start regenerating
var recovering_stamina: bool = false

func _ready():
	# Start everything at max
	GameState.hp = GameState.max_hp
	GameState.energy = GameState.max_energy
	GameState.stamina = GameState.energy
	GameState.satiety = 100
	
	var total_minutes: float = (GameState.hour * 24) + GameState.minute
	prev_status_check = total_minutes
	prev_satiety_check = total_minutes

	EventBus.change_stat.connect(_change_stat)
	#EventBus.start_day.connect(_on_new_day_start)

func _on_new_day_start():
	pass

func _change_stat(stat: String, value: float):
	#print("Changing %s by %s" % [stat, value])
	match stat:
		"hp":
			GameState.hp += value
			
		"energy":
			
			GameState.energy += value
			
		"satiety":
			GameState.satiety += value
			
			if GameState.satiety > 75:
				GameState.satiety_level = 1
			elif GameState.satiety > 50:
				GameState.satiety_level = 2
			elif GameState.satiety > 25:
				GameState.satiety_level = 3
			else:
				GameState.satiety_level = 4
				print("You are starving to death")
		"stamina":
			# Change GameState value
			GameState.stamina += value
			
			# Halt recovery timer if it's running due to a new stamina change
			if not recovery_delay_timer.is_stopped():
				recovery_delay_timer.stop()
			recovering_stamina = false
			
			# Start recovery delay
			if GameState.stamina < GameState.max_stamina and recovery_delay_timer.is_stopped():
				recovery_delay_timer.start(stamina_recovery_delay)
	
	EventBus.stat_changed.emit(stat)

func _physics_process(delta: float) -> void:
	_handle_stamina_recovery(delta)

func _handle_stamina_recovery(delta: float):
	if GameState.stamina >= GameState.energy or not recovering_stamina or not recovery_delay_timer.is_stopped(): return
	#_change_stat("stamina", GameState.stamina_regen_rate * delta)
	GameState.stamina += GameState.stamina_regen_rate * delta
	EventBus.stat_changed.emit("stamina")

func _on_status_check_timer_timeout() -> void:
	var total_minutes: float = (GameState.hour * 60) + GameState.minute
	#print("There have been %s minutes in the day so far.
	#Prev satiety check: %s ago. Prev status check %s ago" % [str(total_minutes), str(total_minutes - prev_satiety_check), str(total_minutes - prev_status_check)])
	
	# Check for times past midnight
	if prev_status_check - total_minutes > 1000:
		prev_status_check = 1440 - prev_status_check
	if prev_satiety_check - total_minutes > 1000:
		prev_satiety_check = 1440 - prev_satiety_check
	
	# Only updates for every in-game minute regardless of time rate
	if total_minutes - prev_status_check < 1.0:
		return
	
	prev_status_check = total_minutes
	
	var energy_change = -GameState.energy_drain_rate * GameState.satiety_level
	if GameState.working:
		energy_change *= 3
	
	_change_stat("energy", energy_change)
	
	_change_stat("satiety", -GameState.satiety_drain_rate)
	
	if GameState.satiety <= 0:
		_change_stat("hp", -GameState.hp_starve_drain_rate)


func _on_recovery_delay_timeout() -> void:
	recovering_stamina = true
