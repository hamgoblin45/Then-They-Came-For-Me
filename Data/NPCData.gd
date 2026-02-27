extends Resource
class_name NPCData

@export var name: String = "NPC"
@export var id: String = ""

@export_group("Pathing")
@export var on_map: bool = true
@export var schedule: ScheduleData
#var start_path_time: float
var waiting_for_player: bool = false

@export var walk_speed: float = 15.0
@export var walk_accel: float = 15.0
@export var run_speed: float = 20.0
@export var run_accel: float = 30.0

@export_group("Dialogue")
@export var default_timeline: String = ""
# Key: World Flag (e.g. curfew_active), Value: Timeline Name in Dialogic (e.g. "frank_nervous")
@export var condition_timelines: Dictionary = {}
@export var interactable: bool = true # Have this get controlled by something like FLEE state too to make them unwilling to talk while scared
@export var conditional_barks: Dictionary = {
	"default": ["Hmm?", "Ahoy there", "What up?"]
	# Key: World Flag, Value: Array of Strings
}
@export var bark_only: bool = false

@export_group("Stats")
@export var loyalty: float = 50.0 # 0-100. Below 40 is a flight/snitch risk.
