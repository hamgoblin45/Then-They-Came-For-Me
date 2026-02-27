extends Node3D

@onready var sprite = $Sprite3D
@onready var viewport = $NeedsViewport
var target_guest: GuestNPC = null
var is_visible: bool = false
var fade_tween: Tween

func _ready():
	sprite.modulate.a = 0.0 # Start invisible
	set_process(false)

func setup(guest: GuestNPC):
	target_guest = guest
	set_process(true)

func _process(delta):
	# Only update the viewport if the sprite is actually visible to the player
	if target_guest and is_visible:
		viewport.update_needs(
			target_guest.npc_data.name, 
			target_guest.satiety, 
			target_guest.stress
		)

func reveal():
	if is_visible: return
	is_visible = true
	
	if fade_tween: fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_property(sprite, "modulate:a", 1.0, 0.3)
	fade_tween.parallel().tween_property(sprite, "scale", Vector3(1.0, 1.0, 1.0), 0.3).from(Vector3(0.5, 0.5, 0.5)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_ui():
	if not is_visible: return
	is_visible = false
	
	if fade_tween: fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	fade_tween.parallel().tween_property(sprite, "scale", Vector3(0.5, 0.5, 0.5), 0.3)
