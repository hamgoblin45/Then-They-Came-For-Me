extends Node3D

@export var item_data: ItemData
@onready var shapecast: ShapeCast3D = $ShapeCast3D

@export_group("Swing Settings")
var swing_power: float = 0.0
var power_max: float = 1.0
var power_build_speed: float = 1.5
@export var stamina_cost_per_sec: float = 20.0
@export var shake_intensity: float = 0.05

@export_group("Visual Offsets")
var default_pos: Vector3 = Vector3.ZERO
var windup_offset: Vector3 = Vector3(0.1, -0.1, 0.2) # Pull back and to the side
var swing_forward_dist: float = 0.7 # How far it swings

enum State {IDLE, CHARGING, SWINGING, RECOVERING}
var current_state = State.IDLE

#func _ready() -> void:
	#shapecast.add_exception(GameState.player.COLLISION_MESH)

func _physics_process(delta: float) -> void:
	if GameState.equipped_item != item_data or GameState.in_dialogue or GameState.ui_open:
		return
	
	match current_state:
		State.IDLE:
			if Input.is_action_just_pressed("click") and GameState.stamina > 5.0:
				
				current_state = State.CHARGING
		State.CHARGING:
			if Input.is_action_pressed("click"):
				# Drain stamina
				#GameState.stamina -= stamina_cost_per_sec * delta
				EventBus.change_stat.emit("stamina", -stamina_cost_per_sec * delta)
				
				# Build up swing power
				swing_power = move_toward(swing_power, power_max, power_build_speed * delta)
				
				# Procedural shaking
				var current_shake = (swing_power / power_max) * shake_intensity
				var shake_offset = Vector3(
					randf_range(-current_shake, current_shake),
					randf_range(-current_shake, current_shake),
					randf_range(-current_shake, current_shake)
				)
				
				# Windup position + shake
				position = lerp(position, default_pos + windup_offset + shake_offset, 0.1)
				rotation_degrees.x = lerp(rotation_degrees.x, 15.0, 0.1)
	
			else:
				_on_release()

func _on_release():
	print("SWINGING with a swing power of ", swing_power)
	if current_state != State.CHARGING: return
	current_state = State.SWINGING
	
	# Calculate how far it swings based on power
	var effective_dist = lerp(0.5, swing_forward_dist, swing_power / power_max)
	var swing_time = 0.15 # Keep it snappy
	
	# Create swing movement
	var swing_tween = create_tween().set_parallel(true)
	
	# Hook motion
	swing_tween.tween_property(self, "position:z", -effective_dist, swing_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	swing_tween.tween_property(self, "position:y", 0.2, swing_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	swing_tween.tween_property(self, "position:x", -0.3, swing_time).set_trans(Tween.TRANS_CUBIC) # sweeps across
	
	# Hook rotation
	swing_tween.tween_property(self, "rotation_degrees:y", 25.0, swing_time)
	swing_tween.tween_property(self, "rotation_degrees:x", -55.0, swing_time)
	swing_tween.tween_property(self, "rotation_degrees:z", -20.0, swing_time)
	
	# If we don't hit anything
	swing_tween.set_parallel(false)
	swing_tween.tween_interval(0.1)
	swing_tween.tween_callback(_reset_to_idle)
	
	# Hit detection only during movement
	await get_tree().create_timer(swing_time * 0.6).timeout # Wait about 60% of the way through the swing for a hit
	
	shapecast.target_position.z = -effective_dist
	
	if _check_hit():
		print("HIT")
		swing_tween.kill() # Stop movement immediately on impact
		_trigger_recoil()
		
func _check_hit() -> bool:
	print("CHECKING HIT")
	shapecast.enabled = true
	shapecast.force_shapecast_update()
	
	if shapecast.is_colliding():
		
		var target = shapecast.get_collider(0) # get the first thing we hit
		var hit_point = shapecast.get_collision_point(0) # Locate where to instance particles
		
		_apply_hit_stop()
		# Impact sound here
		print("COLLIDING with ", target)
		# If you can damage the target, do so
		if target.has_method("take_damage"): # Maybe change this to a class name or something
			# Apply damage based on swing power
			var damage = 10.0 * (1.0 + swing_power)
			target.take_damage(damage)
			print("Hit ", target, " for ", damage)
		#shapecast.enabled = false
		return true
	return false
	#shapecast.enabled = false

func _trigger_recoil():
	print("RECOIL")
	var recoil_tween = create_tween()
	
	var bounce_pos = position + Vector3(0.1, 0.1, 0.3)
	recoil_tween.tween_property(self, "position", bounce_pos, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Move a lil back
	#recoil_tween.tween_property(self, "position", position + Vector3(0.1, 0.1, 0.2), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	#recoil_tween.tween_property(self, "rotation_degrees:x", rotation_degrees.x + 20, 0.1)
	
	# Then back to normal
	#recoil_tween.set_parallel(false)
	recoil_tween.tween_interval(0.06)
	recoil_tween.tween_callback(_reset_to_idle)

func _apply_hit_stop(dur: float = 0.05):
	Engine.time_scale = 0.05 # Slow everything way down
	await get_tree().create_timer(dur * 0.05).timeout
	Engine.time_scale = 1.0 # back to normal

func _reset_to_idle():
	var reset_tween = create_tween().set_parallel(true)
	reset_tween.tween_property(self, "position", default_pos, 0.3).set_trans(Tween.TRANS_SINE)
	reset_tween.tween_property(self, "rotation_degrees", Vector3.ZERO, 0.3)
	
	swing_power = 0.0
	current_state = State.IDLE
	shapecast.enabled = false
