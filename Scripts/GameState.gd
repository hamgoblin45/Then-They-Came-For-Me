extends Node

## -- Time
var weekday: String = "Monday"
var day: int = 1
var hour: int = 8
var minute: int = 0

var day_start: float = 8.0
var day_end: float = 2.0 # Measured in hours, above 24 is in the AM

var time: float = 8.0 # in hours
var cycle_time: float = 0.33 # between 0.0 and 1.0

var time_speed: float = 1.0
var paused: bool = false

## -- Interface
var ui_open: bool = false
var in_dialogue: bool = false
var shopping: bool = false # Dictates how inventory UI will react, primarily Using an item vs Selling it
var money: float = 100
var pockets_inventory: InventoryData
var active_hotbar_index: int = -1
var equipped_item: ItemData

## -- Player / 3D Controller
var player: CharacterBody3D
var held_item
var talking_to: NPC
var can_move: bool = true

## -- Status
var hp: float = 50.0
var max_hp: float = 100.0

var max_energy: float = 100.0
var energy: float = 40.0: # Only refills on a new day / eating
	set(value):
		energy = clamp(value, 0 , max_energy)
		if stamina > energy:
			stamina = energy
var energy_drain_rate: float = 0.05 # How fast energy drains over time

var max_stamina: float = 100.0
var stamina: float = 100.0:
	set(value):
		stamina = clamp(value, 0, energy)
var stamina_regen_rate: float = 15.0

var satiety: float = 12.0:
	set(value): satiety = clamp(value, 0, 100)
var satiety_level: int = 1 # 1-4, incemental satiety categories. This is multiplied by energy drain to make you tired faster when hungry
var satiety_drain_rate: float = 0.05 # How quickly you get hungry
var hp_starve_drain_rate: float = 0.05 # How much dmg you take when starving

var working: bool = false

## -- Regime / World
var legal_threshold: float = 2.0 # Items w/ a contraband level above this are illegal
var regime_suspicion: float = 0.0:
	set(value): regime_suspicion = clamp(value, 0, 100)
var resistance: float = 0.0:
	set(value): resistance = clamp(value, 0, 100)
var raid_in_progress: bool = false

# - Memory
var world_flags: Dictionary = {
	# This is where you will keep keys like "first_warning_received" or "doug_arrested" with bool values
	# Can just use something like "set GameState.world_flags.neighbor_arrested = true" in Dialogic
}

var objectives: Array[ObjectiveData]

## -- Hiding NPCs
var guests: Array[NPC]
var hidden_guest_datas: Array[NPCData] = []
var leading_npc: NPC


func set_flag(id: String, value: bool):
	world_flags[id] = value
	EventBus.world_changed.emit(id, value) 

func get_flag(id: String) -> bool:
	return world_flags.get(id, false)
