extends Node

@export var sounds: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# --- INTERNAL HELPER ---
func _get_stream(sound_name: String) -> AudioStream:
	if not sounds.has(sound_name):
		push_warning("AudioManager: Sound '%s' not found in library." % sound_name)
		return null
		
	var entry = sounds[sound_name]
	if entry is Array:
		if entry.is_empty(): return null
		return entry.pick_random() as AudioStream
	elif entry is AudioStream:
		return entry
		
	return null

# ---------------------------------------------------------
# 1. 2D AUDIO (UI, Music, Global)
# ---------------------------------------------------------
func play_2d(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	var stream = _get_stream(sound_name)
	if not stream: return null
		
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	
	# NEW: Add to a group matching the sound name
	player.add_to_group(sound_name) 
	
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	
	return player

# ---------------------------------------------------------
# 2. 3D AUDIO (Spatial)
# ---------------------------------------------------------
func play_3d(sound_name: String, position: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer3D:
	var stream = _get_stream(sound_name)
	if not stream: return null
		
	var player = AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.max_distance = 18.0 
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	
	# NEW: Add to a group matching the sound name
	player.add_to_group(sound_name) 
	
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(player)
		player.global_position = position
		player.play()
		player.finished.connect(player.queue_free)
	else:
		player.queue_free()
		return null
		
	return player

# ---------------------------------------------------------
# 3. STOPPING AUDIO
# ---------------------------------------------------------
func stop_audio(sound_name: String):
	# NEW: Safely stop and delete all sounds in the target group, 
	# regardless of their exact node name or 2D/3D status!
	for player in get_tree().get_nodes_in_group(sound_name):
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
