extends Camera3D

var shake_intensity: float = 0.0
var shake_duration: float = 0.0

func _ready() -> void:
	EventBus.request_screen_shake.connect(_trigger_shake)

func _trigger_shake(intensity: float, duration: float) -> void:
	shake_intensity = intensity
	shake_duration = duration

func _process(delta: float) -> void:
	if shake_duration > 0:
		shake_duration -= delta
		
		# Generate random offsets based on intensity
		h_offset = randf_range(-shake_intensity, shake_intensity)
		v_offset = randf_range(-shake_intensity, shake_intensity)
		
		# Decay intensity over time for a smooth stop
		shake_intensity = lerp(shake_intensity, 0.0, 5.0 * delta)
	else:
		# Reset offsets when shake is done
		h_offset = 0.0
		v_offset = 0.0
