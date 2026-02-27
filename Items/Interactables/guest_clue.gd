extends RigidBody3D
class_name GuestClue

@export var interact_area: Interactable

@export_group("Suspicion Settings")
@export var suspicion_contribution: float = 15.0 
@export var investigation_time: float = 3.0 
@export var bark_line: String = "What's this doing here?"

var is_discovered: bool = false
var held: bool = false

func _ready() -> void:
	add_to_group("clues")
	
	if interact_area:
		interact_area.interacted.connect(_on_interacted)
	else:
		push_warning("GuestClue %s is missing its Interactable Area!" % name)

func _on_interacted(type: String, engaged: bool):
	match type:
		"click":
			if engaged:
				EventBus.item_grabbed.emit(self)
				held = true
			else:
				EventBus.item_dropped.emit()
				held = false

func on_spotted(officer: NPC):
	if is_discovered: return
	is_discovered = true
	
	print("Clue spotted by officer: %s" % name)
	
	# Stop the officer and make them investigate
	officer.command_stop()
	officer.spawn_bark(bark_line)
	officer.look_at_target(self)
	
	SearchManager.clue_discovered(self)
