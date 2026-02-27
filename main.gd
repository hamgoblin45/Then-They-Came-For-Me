extends Node3D
# Mostly just for running test stuff
@onready var test_refugee: NPC = $NPCs/TestRefugee


func _ready() -> void:
	GameState.hidden_guest_datas.append(test_refugee.npc_data)
	GameState.guests.append(test_refugee)
	#GameState.leading_npc = test_refugee
	#test_refugee.state = test_refugee.FOLLOWING
