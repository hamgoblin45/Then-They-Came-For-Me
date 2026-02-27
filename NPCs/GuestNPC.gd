extends NPC
class_name GuestNPC

var is_inside_house: bool = false
var is_hidden: bool = false
var current_hiding_spot: HidingSpot = null
var target_hiding_spot: HidingSpot = null

# --- NEEDS SYSTEM ---
var satiety: float = 100.0 # Starts at 100 (Full)
var stress: float = 0.0    # 0 is calm (this stays the same)

@onready var needs_billboard = $GuestNeedsBillboard
var look_timer: float = 0.0
var is_being_looked_at: bool = false

# --- HOLD-TO-GIVE SYSTEM ---
var give_timer: float = 0.0
var give_duration: float = 1.0
var last_equipped_item: ItemData = null
var has_fed_current_press: bool = false

func _ready() -> void:
	super._ready()
	if needs_billboard:
		needs_billboard.setup(self)
	EventBus.looking_at_interactable.connect(_on_look_change)

func _process(delta: float) -> void:
	# 1. Dynamic UI Updates
	if GameState.equipped_item != last_equipped_item:
		last_equipped_item = GameState.equipped_item
		# NEW: Only show the "Hold to Give" prompt if they are actually a guest!
		if GameState.equipped_item is ConsumableData and is_inside_house:
			interact_area.interact_text = "Tap: Talk | Hold: Give " + GameState.equipped_item.name
		else:
			interact_area.interact_text = "Talk"
			
		if is_being_looked_at:
			EventBus.looking_at_interactable.emit(interact_area, true)

	if is_being_looked_at:
		# 2. Billboard Reveal Timer
		look_timer += delta
		
		# NEW: Only reveal the billboard if they are in the house!
		if look_timer >= 1.0 and needs_billboard and is_inside_house:
			needs_billboard.reveal()
			
		# 3. Hold-to-Give Logic (Only allow feeding if they are a guest!)
		if GameState.equipped_item is ConsumableData and is_inside_house:
			# Track when the player initially clicks
			if Input.is_action_just_pressed("interact"):
				has_fed_current_press = false
				
			if Input.is_action_pressed("interact"):
				if not has_fed_current_press:
					give_timer += delta
					EventBus.consume_progress.emit(give_timer / give_duration)
					
					if give_timer >= give_duration:
						_feed_guest(GameState.equipped_item)
						_reset_give_state()
						has_fed_current_press = true
						
			elif Input.is_action_just_released("interact"):
				if not has_fed_current_press and give_timer > 0.0:
					super._handle_interaction()
					
				_reset_give_state()
				has_fed_current_press = false
		else:
			_reset_give_state()
			
	else:
		look_timer = 0.0
		_reset_give_state()
		if needs_billboard:
			needs_billboard.hide_ui()

func _reset_give_state():
	if give_timer > 0:
		give_timer = 0.0
		EventBus.consume_progress.emit(0.0)

# OVERRIDE: Prevent immediate dialogue if holding food
func _handle_interaction():
	if GameState.equipped_item is ConsumableData:
		return # Do nothing on initial press, let the tap/hold logic handle it
		
	# Normal behavior if holding a non-consumable (like a hammer or nothing)
	super._handle_interaction()

func _on_look_change(interactable: Interactable, looking: bool):
	if interactable == interact_area:
		is_being_looked_at = looking
		
		if looking:
			last_equipped_item = GameState.equipped_item
			# NEW: Match the logic here so the initial text is correct
			if GameState.equipped_item is ConsumableData and is_inside_house:
				interact_area.interact_text = "Tap: Talk | Hold: Give " + GameState.equipped_item.name
			else:
				interact_area.interact_text = "Talk"

func _feed_guest(item: ConsumableData):
	var nut = item.effects.get("satiety", 0.0)
	var s_rel = item.effects.get("stress", 0.0)
	var helped = false

	# NEW: Prevent overfeeding
	if nut > 0 and satiety > 90.0:
		spawn_bark("I'm too full right now.")
		return # Exit the function completely so the item isn't consumed

	if nut != 0:
		# We add to satiety now!
		satiety = clamp(satiety + nut, 0.0, 100.0) 
		helped = true
	
	# Stress still subtracts (lower is better)
	if s_rel != 0:
		stress = clamp(stress - s_rel, 0.0, 100.0)
		helped = true
		
	if helped:
		spawn_bark("Thank you, I really needed this.")
		print("GuestNPC: Fed %s. Satiety: %s, Stress: %s" % [item.name, satiety, stress])
		EventBus.removing_item.emit(item, 1, null)
	else:
		spawn_bark("I don't need this right now...")

func command_go_hide(spot: HidingSpot):
	spot.reserved_by = self
	target_hiding_spot = spot
	
	spawn_bark("I'm going!")
	command_move_to(spot.global_position)
	
	# Wait until the NavigationAgent says we have arrived
	await destination_reached
	
	# Double check we are still trying to hide here (in case they got interrupted)
	if target_hiding_spot == spot:
		_enter_hiding_spot()

func _enter_hiding_spot():
	is_hidden = true
	if target_hiding_spot:
		current_hiding_spot = target_hiding_spot
		target_hiding_spot._assign_occupant(self)
		target_hiding_spot = null
		
		# Optional: Play a door shut sound!
		# AudioManager.play_3d("closet_shut", global_position)

func exit_hiding():
	is_hidden = false
	current_hiding_spot = null
	show()
	collision_layer = 1
