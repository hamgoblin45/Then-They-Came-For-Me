extends Node3D

@onready var interactable: Interactable = $Interactable

@onready var lamp_audio: AudioStreamPlayer3D = $LampAudio
@onready var lamp_light: OmniLight3D = %LampLight


func _ready():
	interactable.interacted.connect(_interact)

func _interact(_type: String, engaged: bool):
	if engaged:
		lamp_light.visible = not lamp_light.visible
		
		if lamp_light.visible:
			lamp_audio.stream = preload("uid://b1fxygtu6jhbr") # Switch on sound
		else:
			lamp_audio.stream = preload("uid://4pfslosd8bp1") # Switch off sound
			
		lamp_audio.play()
