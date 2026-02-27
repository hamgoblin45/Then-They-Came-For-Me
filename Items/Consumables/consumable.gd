extends Node3D

@export var item_data: ConsumableData
@export var consume_speed: float = 2.0 # seconds to eat whole thing

var timer: float = 0.0
var is_eating: bool = false

var default_pos: Vector3 = Vector3.ZERO
var eating_pos: Vector3 = Vector3(0, -0.15, -0.25) # Closer to face

func _physics_process(delta: float) -> void:
	if GameState.equipped_item != item_data or GameState.in_dialogue or GameState.ui_open:
		_reset_consume()
		return
	
	if Input.is_action_pressed("click"):
		_process_consume(delta)
	else:
		_reset_consume()

func _process_consume(delta: float):
	is_eating = true
	timer += delta
	
	var progress = timer / consume_speed
	
	var shake = Vector3(randf_range(-0.005, 0.005), randf_range(-0.005, 0.005), 0) * progress
	position = lerp(position, eating_pos + shake, 0.1)
	
	if timer >= consume_speed:
		_on_consume_complete()
	
	EventBus.consume_progress.emit(timer / consume_speed)

func _reset_consume():
	if not is_eating: return
	is_eating = false
	timer = 0.0
	EventBus.consume_progress.emit(0.0)
	#Smootly return to idle
	var tween = create_tween()
	tween.tween_property(self, "position", default_pos, 0.2)

func _on_consume_complete():
	print("Item consumed!")
	for stat_name in item_data.effects:
		var amount = item_data.effects[stat_name]
		if amount != 0:
			print("Recovered %s %s" % [str(amount), stat_name])
			EventBus.change_stat.emit(stat_name, amount)
	
	EventBus.removing_item.emit(item_data, 1, null)
	_check_stack_depleted()
	_reset_consume()

func _check_stack_depleted():
	if GameState.equipped_item == item_data:
		pass
